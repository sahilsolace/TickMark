import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import '../database/database_helper.dart';
import '../models/daily_summary_model.dart';
import '../models/employee_model.dart';
import '../models/task_model.dart';

enum AppViewMode {
  full,
  mini,
}

class TimeTrackingController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Reactive state
  final RxList<TaskModel> tasks = <TaskModel>[].obs;
  final Rx<DailySummaryModel> dailySummary = DailySummaryModel.empty('').obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;
  final Rx<AppViewMode> viewMode = AppViewMode.full.obs;
  final Rxn<EmployeeModel> employee = Rxn<EmployeeModel>();
  final RxBool isLoading = false.obs;

  // Active running timer state
  final RxnInt activeTaskId = RxnInt();
  final RxnString activeWorkDate = RxnString();
  final Rxn<DateTime> activeSessionStartTime = Rxn<DateTime>();
  int _sessionAccumulatedSeconds = 0;
  int _baseTaskAccumulatedSeconds = 0;
  int? _activeTimeEntryId;

  Timer? _tickerTimer;
  Timer? _periodicSyncTimer;

  // Window geometry preservation
  Size savedFullSize = const Size(840, 680);
  Offset? savedFullPosition;

  // Date boundaries
  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get yesterday => today.subtract(const Duration(days: 1));

  bool get isToday => _isSameDay(selectedDate.value, today);
  bool get isYesterday => _isSameDay(selectedDate.value, yesterday);
  bool get canGoNext => !isToday; // Cannot navigate to future dates
  bool get canGoPrevious => true; // Can browse past dates to view records
  bool get hasActiveTimer => activeTaskId.value != null;

  String get selectedDateIso => _formatDateToIso(selectedDate.value);

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateToIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  @override
  void onClose() {
    _tickerTimer?.cancel();
    _periodicSyncTimer?.cancel();
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    isLoading.value = true;
    selectedDate.value = today;

    try {
      employee.value = await _dbHelper.getEmployee();
      await loadTasksForSelectedDate();
      await checkInitialWindowSize();
    } catch (e) {
      debugPrint('Initialization error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> checkInitialWindowSize() async {
    try {
      final size = await windowManager.getSize();
      if (size.width < 500) {
        viewMode.value = AppViewMode.mini;
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // DATE NAVIGATION
  // ---------------------------------------------------------------------------

  void setDate(DateTime newDate) {
    DateTime target = DateTime(newDate.year, newDate.month, newDate.day);
    if (target.isAfter(today)) {
      target = today;
    }

    selectedDate.value = target;
    loadTasksForSelectedDate();
  }

  void previousDay() {
    setDate(selectedDate.value.subtract(const Duration(days: 1)));
  }

  void nextDay() {
    if (canGoNext) {
      setDate(selectedDate.value.add(const Duration(days: 1)));
    }
  }

  void goToToday() {
    setDate(today);
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------

  Future<void> loadTasksForSelectedDate() async {
    isLoading.value = true;

    final dateIso = selectedDateIso;
    try {
      final dbTasks = await _dbHelper.getTasksForDate(dateIso);
      dailySummary.value = await _dbHelper.getDailySummary(dateIso);

      // Reconcile with active timer if running on this date
      tasks.assignAll(dbTasks.map((task) {
        if (task.id == activeTaskId.value && activeSessionStartTime.value != null) {
          final sessionSeconds = DateTime.now().difference(activeSessionStartTime.value!).inSeconds;
          return task.copyWith(
            isRunning: true,
            activeStartTimestamp: activeSessionStartTime.value,
            totalDurationSeconds: _baseTaskAccumulatedSeconds + sessionSeconds,
          );
        }
        return task;
      }).toList());

      // Recalculate daily summary if an active timer is running for today
      if (activeTaskId.value != null && activeWorkDate.value == dateIso && activeSessionStartTime.value != null) {
        _recalculateDailySummaryWithActiveSession();
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshEmployee() async {
    employee.value = await _dbHelper.getEmployee();
  }

  // ---------------------------------------------------------------------------
  // TASK MANAGEMENT (Only Today can add tasks)
  // ---------------------------------------------------------------------------

  Future<TaskModel> addTask({
    required int projectId,
    required String taskDescription,
    required bool billable,
  }) async {
    // Tasks can ONLY be added for Today
    final dateIso = _formatDateToIso(today);
    final newTask = await _dbHelper.createTask(
      projectId: projectId,
      taskDescription: taskDescription,
      billable: billable,
      workDate: dateIso,
    );

    // If currently viewing a past date, automatically switch to today
    if (!isToday) {
      selectedDate.value = today;
    }

    await loadTasksForSelectedDate();
    return newTask;
  }

  Future<void> deleteTask(int taskId) async {
    // If active task is being deleted, stop timer first
    if (activeTaskId.value == taskId) {
      await stopTimer(taskId);
    }

    await _dbHelper.deleteTask(taskId);
    await loadTasksForSelectedDate();
  }

  // ---------------------------------------------------------------------------
  // TIMER CONTROLS (Only Today's tasks can be tracked)
  // ---------------------------------------------------------------------------

  /// Starts or resumes tracking for a task.
  /// If another task was running, it is automatically paused first!
  Future<void> startOrResumeTimer(TaskModel task) async {
    final taskId = task.id;
    if (taskId == null) return;

    // Timers can only be run for Today's tasks
    if (task.workDate != _formatDateToIso(today)) {
      debugPrint('Timers can only be run on Today tasks.');
      return;
    }

    // If this task is already running, do nothing
    if (activeTaskId.value == taskId) return;

    // 1. If another task is currently active, pause it automatically
    if (activeTaskId.value != null) {
      await pauseActiveTimer();
    }

    // Ensure employee exists
    if (employee.value == null) {
      employee.value = await _dbHelper.getEmployee();
    }

    final now = DateTime.now();
    activeTaskId.value = taskId;
    activeWorkDate.value = task.workDate;
    activeSessionStartTime.value = now;
    _sessionAccumulatedSeconds = 0;
    _baseTaskAccumulatedSeconds = task.totalDurationSeconds;

    // Insert active entry into SQLite
    _activeTimeEntryId = await _dbHelper.startTimeEntry(
      taskId: taskId,
      employeeId: employee.value?.id ?? 1,
      workDate: task.workDate,
      startTimestamp: now,
    );

    // Update in-memory tasks
    tasks.assignAll(tasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(
          isRunning: true,
          activeStartTimestamp: now,
        );
      }
      return t;
    }).toList());

    _startTicker();
    _startPeriodicSync();
  }

  /// Pauses the currently active timer.
  Future<void> pauseActiveTimer() async {
    if (activeTaskId.value == null || activeSessionStartTime.value == null) return;

    final now = DateTime.now();
    final elapsedSessionSeconds = now.difference(activeSessionStartTime.value!).inSeconds;

    _tickerTimer?.cancel();
    _tickerTimer = null;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;

    final entryId = _activeTimeEntryId;
    final taskId = activeTaskId.value;
    final totalTaskSeconds = _baseTaskAccumulatedSeconds + elapsedSessionSeconds;

    if (entryId != null) {
      await _dbHelper.stopTimeEntry(
        entryId: entryId,
        endTimestamp: now,
        durationSeconds: elapsedSessionSeconds > 0 ? elapsedSessionSeconds : 0,
      );
    }

    activeTaskId.value = null;
    activeWorkDate.value = null;
    _activeTimeEntryId = null;
    activeSessionStartTime.value = null;
    _sessionAccumulatedSeconds = 0;
    _baseTaskAccumulatedSeconds = 0;

    // Update in-memory task
    tasks.assignAll(tasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(
          isRunning: false,
          activeStartTimestamp: null,
          totalDurationSeconds: totalTaskSeconds,
        );
      }
      return t;
    }).toList());

    // Reload summary to reflect persisted changes
    dailySummary.value = await _dbHelper.getDailySummary(selectedDateIso);
  }

  /// Stops tracking for a task.
  Future<void> stopTimer(int taskId) async {
    if (activeTaskId.value == taskId) {
      await pauseActiveTimer();
    }
  }

  // ---------------------------------------------------------------------------
  // TICKER & SYNC
  // ---------------------------------------------------------------------------

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (activeTaskId.value == null || activeSessionStartTime.value == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      _sessionAccumulatedSeconds = now.difference(activeSessionStartTime.value!).inSeconds;
      final currentTotal = _baseTaskAccumulatedSeconds + _sessionAccumulatedSeconds;

      // Update the active task in memory
      tasks.assignAll(tasks.map((t) {
        if (t.id == activeTaskId.value) {
          return t.copyWith(
            isRunning: true,
            totalDurationSeconds: currentTotal,
          );
        }
        return t;
      }).toList());

      if (activeWorkDate.value == selectedDateIso) {
        _recalculateDailySummaryWithActiveSession();
      }
    });
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    // Persist every 10 seconds to guard against crashes or power loss
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_activeTimeEntryId != null && activeSessionStartTime.value != null) {
        final elapsed = DateTime.now().difference(activeSessionStartTime.value!).inSeconds;
        await _dbHelper.updateActiveEntryDuration(_activeTimeEntryId!, elapsed);
      }
    });
  }

  void _recalculateDailySummaryWithActiveSession() {
    int billable = 0;
    int nonBillable = 0;

    for (final task in tasks) {
      if (task.billable) {
        billable += task.totalDurationSeconds;
      } else {
        nonBillable += task.totalDurationSeconds;
      }
    }

    dailySummary.value = DailySummaryModel(
      workDate: selectedDateIso,
      totalSeconds: billable + nonBillable,
      billableSeconds: billable,
      nonBillableSeconds: nonBillable,
      totalTasks: tasks.length,
    );
  }

  // ---------------------------------------------------------------------------
  // WINDOW MODE SWITCHING
  // ---------------------------------------------------------------------------

  Future<void> switchToMiniMode() async {
    try {
      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      // Only save if currently in full mode
      if (viewMode.value == AppViewMode.full && size.width > 500) {
        savedFullSize = size;
        savedFullPosition = pos;
      }

      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(const Size(300, 110));
      await windowManager.setMaximumSize(const Size(520, 220));
      await windowManager.setSize(const Size(340, 120));
      await windowManager.setAlwaysOnTop(true);
    } catch (e) {
      debugPrint('Error transitioning to mini mode: $e');
    }

    viewMode.value = AppViewMode.mini;
  }

  Future<void> switchToFullMode() async {
    try {
      await windowManager.setMaximumSize(const Size(3840, 2160));
      await windowManager.setMinimumSize(const Size(600, 480));
      await windowManager.setSize(savedFullSize);
      if (savedFullPosition != null) {
        await windowManager.setPosition(savedFullPosition!);
      }
      await windowManager.setAlwaysOnTop(false);
    } catch (e) {
      debugPrint('Error transitioning to full mode: $e');
    }

    viewMode.value = AppViewMode.full;
  }

  /// Clean shutdown helper called before window closes.
  Future<void> handleAppClosing() async {
    if (activeTaskId.value != null) {
      await pauseActiveTimer();
    }
  }
}
