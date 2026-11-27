import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../controllers/time_tracking_controller.dart';
import '../models/task_model.dart';
import '../models/daily_summary_model.dart';
import '../models/employee_model.dart';

/// Service facade maintaining backward compatibility with tests and services
/// while delegating state to [TimeTrackingController].
class TimeTrackingService extends ChangeNotifier {
  static final TimeTrackingService _instance = TimeTrackingService._internal();
  factory TimeTrackingService() => _instance;
  TimeTrackingService._internal() {
    _ensureController();
  }

  TimeTrackingController _getController() {
    if (Get.isRegistered<TimeTrackingController>()) {
      return Get.find<TimeTrackingController>();
    }
    return Get.put<TimeTrackingController>(TimeTrackingController(), permanent: true);
  }

  void _ensureController() {
    final controller = _getController();
    controller.tasks.listen((_) => notifyListeners());
    controller.dailySummary.listen((_) => notifyListeners());
    controller.selectedDate.listen((_) => notifyListeners());
    controller.viewMode.listen((_) => notifyListeners());
    controller.isLoading.listen((_) => notifyListeners());
    controller.activeTaskId.listen((_) => notifyListeners());
  }

  // Delegated getters
  DateTime get today => _getController().today;
  DateTime get yesterday => _getController().yesterday;
  bool get isToday => _getController().isToday;
  bool get isYesterday => _getController().isYesterday;
  bool get canGoNext => _getController().canGoNext;
  bool get canGoPrevious => _getController().canGoPrevious;
  DateTime get selectedDate => _getController().selectedDate.value;
  String get selectedDateIso => _getController().selectedDateIso;
  List<TaskModel> get tasks => _getController().tasks;
  DailySummaryModel get dailySummary => _getController().dailySummary.value;
  EmployeeModel? get employee => _getController().employee.value;
  bool get isLoading => _getController().isLoading.value;
  int? get activeTaskId => _getController().activeTaskId.value;
  String? get activeWorkDate => _getController().activeWorkDate.value;
  bool get hasActiveTimer => _getController().hasActiveTimer;

  // Delegated methods
  Future<void> initialize() => _getController().initialize();
  void setDate(DateTime newDate) => _getController().setDate(newDate);
  void previousDay() => _getController().previousDay();
  void nextDay() => _getController().nextDay();
  void goToToday() => _getController().goToToday();
  Future<void> loadTasksForSelectedDate() => _getController().loadTasksForSelectedDate();
  Future<void> refreshEmployee() => _getController().refreshEmployee();

  Future<TaskModel> addTask({
    required int projectId,
    required String taskDescription,
    required bool billable,
  }) =>
      _getController().addTask(
        projectId: projectId,
        taskDescription: taskDescription,
        billable: billable,
      );

  Future<void> deleteTask(int taskId) => _getController().deleteTask(taskId);

  Future<void> startOrResumeTimer(TaskModel task) => _getController().startOrResumeTimer(task);
  Future<void> pauseActiveTimer() => _getController().pauseActiveTimer();
  Future<void> stopTimer(int taskId) => _getController().stopTimer(taskId);
  Future<void> handleAppClosing() => _getController().handleAppClosing();
}
