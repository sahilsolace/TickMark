import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/task_model.dart';
import '../models/daily_summary_model.dart';
import '../models/employee_model.dart';

class TimeTrackingService extends ChangeNotifier {
  static final TimeTrackingService _instance = TimeTrackingService._internal();
  factory TimeTrackingService() => _instance;
  TimeTrackingService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Active running timer state
  int? _activeTaskId;
  String? _activeWorkDate;
  int? _activeTimeEntryId;
  DateTime? _activeSessionStartTime;
  int _sessionAccumulatedSeconds = 0;
  int _baseTaskAccumulatedSeconds = 0;

  Timer? _tickerTimer;
  Timer? _periodicSyncTimer;

  // Selected date state
  DateTime _selectedDate = DateTime.now();

  // Cached data for current view
  List<TaskModel> _tasks = [];
  DailySummaryModel _dailySummary = DailySummaryModel.empty('');
  EmployeeModel? _employee;
  bool _isLoading = false;

  // Date helpers: user can only add tasks today; rest (past dates) are read-only
  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get yesterday => today.subtract(const Duration(days: 1));

  bool get isToday => _isSameDay(_selectedDate, today);
  bool get isYesterday => _isSameDay(_selectedDate, yesterday);
  bool get canGoNext => !isToday; // Can go forward up to today, but cannot go to future dates
  bool get canGoPrevious => true; // Can browse past dates to view records

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Getters
  DateTime get selectedDate => _selectedDate;
  String get selectedDateIso => _formatDateToIso(_selectedDate);
  List<TaskModel> get tasks => _tasks;
  DailySummaryModel get dailySummary => _dailySummary;
  EmployeeModel? get employee => _employee;
  bool get isLoading => _isLoading;
  int? get activeTaskId => _activeTaskId;
  String? get activeWorkDate => _activeWorkDate;
  bool get hasActiveTimer => _activeTaskId != null;

  String _formatDateToIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    _isLoading = true;
    _selectedDate = today;
    notifyListeners();

    try {
      _employee = await _dbHelper.getEmployee();
      await loadTasksForSelectedDate();
    } catch (e) {
      debugPrint('Initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // DATE NAVIGATION
  // ---------------------------------------------------------------------------

  void setDate(DateTime newDate) {
    DateTime target = DateTime(newDate.year, newDate.month, newDate.day);
    // Boundary enforcement: cannot navigate into future dates
    if (target.isAfter(today)) {
      target = today;
    }

    _selectedDate = target;
    loadTasksForSelectedDate();
  }

  void previousDay() {
    setDate(_selectedDate.subtract(const Duration(days: 1)));
  }

  void nextDay() {
    if (canGoNext) {
      setDate(_selectedDate.add(const Duration(days: 1)));
    }
  }

  void goToToday() {
    setDate(today);
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------

  Future<void> loadTasksForSelectedDate() async {
    _isLoading = true;
    notifyListeners();

    final dateIso = selectedDateIso;
    try {
      final dbTasks = await _dbHelper.getTasksForDate(dateIso);
      _dailySummary = await _dbHelper.getDailySummary(dateIso);

      // Reconcile with active timer if running on this date
      _tasks = dbTasks.map((task) {
        if (task.id == _activeTaskId && _activeSessionStartTime != null) {
          final sessionSeconds = DateTime.now().difference(_activeSessionStartTime!).inSeconds;
          return task.copyWith(
            isRunning: true,
            activeStartTimestamp: _activeSessionStartTime,
            totalDurationSeconds: _baseTaskAccumulatedSeconds + sessionSeconds,
          );
        }
        return task;
      }).toList();

      // Recalculate daily summary if an active timer is running for today
      if (_activeTaskId != null && _activeWorkDate == dateIso && _activeSessionStartTime != null) {
        _recalculateDailySummaryWithActiveSession();
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshEmployee() async {
    _employee = await _dbHelper.getEmployee();
    notifyListeners();
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

    // If currently viewing a past date, automatically switch to today to view the new task
    if (!isToday) {
      _selectedDate = today;
    }

    await loadTasksForSelectedDate();
    return newTask;
  }

  Future<void> deleteTask(int taskId) async {
    // If active task is being deleted, stop timer first
    if (_activeTaskId == taskId) {
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
    if (_activeTaskId == taskId) return;

    // 1. If another task is currently active, pause it automatically
    if (_activeTaskId != null) {
      await pauseActiveTimer();
    }

    // Ensure employee exists
    _employee ??= await _dbHelper.getEmployee();

    final now = DateTime.now();
    _activeTaskId = taskId;
    _activeWorkDate = task.workDate;
    _activeSessionStartTime = now;
    _sessionAccumulatedSeconds = 0;
    _baseTaskAccumulatedSeconds = task.totalDurationSeconds;

    // Insert active entry into SQLite
    _activeTimeEntryId = await _dbHelper.startTimeEntry(
      taskId: taskId,
      employeeId: _employee?.id ?? 1,
      workDate: task.workDate,
      startTimestamp: now,
    );

    // Update in-memory tasks
    _tasks = _tasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(
          isRunning: true,
          activeStartTimestamp: now,
        );
      }
      return t;
    }).toList();

    _startTicker();
    _startPeriodicSync();
    notifyListeners();
  }

  /// Pauses the currently active timer.
  Future<void> pauseActiveTimer() async {
    if (_activeTaskId == null || _activeSessionStartTime == null) return;

    final now = DateTime.now();
    final elapsedSessionSeconds = now.difference(_activeSessionStartTime!).inSeconds;

    _tickerTimer?.cancel();
    _tickerTimer = null;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;

    final entryId = _activeTimeEntryId;
    final taskId = _activeTaskId;
    final totalTaskSeconds = _baseTaskAccumulatedSeconds + elapsedSessionSeconds;

    if (entryId != null) {
      await _dbHelper.stopTimeEntry(
        entryId: entryId,
        endTimestamp: now,
        durationSeconds: elapsedSessionSeconds > 0 ? elapsedSessionSeconds : 0,
      );
    }

    _activeTaskId = null;
    _activeWorkDate = null;
    _activeTimeEntryId = null;
    _activeSessionStartTime = null;
    _sessionAccumulatedSeconds = 0;
    _baseTaskAccumulatedSeconds = 0;

    // Update in-memory task
    _tasks = _tasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(
          isRunning: false,
          activeStartTimestamp: null,
          totalDurationSeconds: totalTaskSeconds,
        );
      }
      return t;
    }).toList();

    // Reload summary to reflect persisted changes
    _dailySummary = await _dbHelper.getDailySummary(selectedDateIso);
    notifyListeners();
  }

  /// Stops tracking for a task.
  Future<void> stopTimer(int taskId) async {
    if (_activeTaskId == taskId) {
      await pauseActiveTimer();
    }
  }

  // ---------------------------------------------------------------------------
  // TICKER & SYNC
  // ---------------------------------------------------------------------------

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeTaskId == null || _activeSessionStartTime == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      _sessionAccumulatedSeconds = now.difference(_activeSessionStartTime!).inSeconds;
      final currentTotal = _baseTaskAccumulatedSeconds + _sessionAccumulatedSeconds;

      // Update the active task in memory
      bool hasChanges = false;
      _tasks = _tasks.map((t) {
        if (t.id == _activeTaskId) {
          hasChanges = true;
          return t.copyWith(
            isRunning: true,
            totalDurationSeconds: currentTotal,
          );
        }
        return t;
      }).toList();

      if (_activeWorkDate == selectedDateIso) {
        _recalculateDailySummaryWithActiveSession();
      }

      if (hasChanges) {
        notifyListeners();
      }
    });
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    // Persist every 10 seconds to guard against unexpected crashes or power loss
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_activeTimeEntryId != null && _activeSessionStartTime != null) {
        final elapsed = DateTime.now().difference(_activeSessionStartTime!).inSeconds;
        await _dbHelper.updateActiveEntryDuration(_activeTimeEntryId!, elapsed);
      }
    });
  }

  void _recalculateDailySummaryWithActiveSession() {
    int billable = 0;
    int nonBillable = 0;

    for (final task in _tasks) {
      if (task.billable) {
        billable += task.totalDurationSeconds;
      } else {
        nonBillable += task.totalDurationSeconds;
      }
    }

    _dailySummary = DailySummaryModel(
      workDate: selectedDateIso,
      totalSeconds: billable + nonBillable,
      billableSeconds: billable,
      nonBillableSeconds: nonBillable,
      totalTasks: _tasks.length,
    );
  }

  /// Clean shutdown helper called before window closes.
  Future<void> handleAppClosing() async {
    if (_activeTaskId != null) {
      await pauseActiveTimer();
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
}
