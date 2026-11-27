import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tickmark/services/timesheet_services.dart';
import 'package:window_manager/window_manager.dart';
import '../controllers/time_tracking_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_header_bar.dart';
import '../widgets/date_navigation_bar.dart';
import '../widgets/daily_summary_cards.dart';
import '../widgets/task_creation_card.dart';
import '../widgets/task_card_item.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/mini_tracker_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  final TimeTrackingController controller = Get.isRegistered<TimeTrackingController>()
      ? Get.find<TimeTrackingController>()
      : Get.put<TimeTrackingController>(TimeTrackingController(), permanent: true);

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    TimesheetServices.getProject();
    super.initState();
    windowManager.addListener(this);
    controller.initialize();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Gracefully persist active timer before closing
    await controller.handleAppClosing();
    await windowManager.destroy();
  }

  void _openSettings() {
    SettingsDialog.show(context);
  }

  Future<void> _syncNow() async {
    final selectedDate = controller.selectedDateIso;
    await TimesheetServices.syncTimesheet(date: selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // If in Mini Tracker Mode: show ONLY the current ongoing task
      if (controller.viewMode.value == AppViewMode.mini) {
        return MiniTrackerWidget(
          onExpandToFull: controller.switchToFullMode,
        );
      }

      // Full Application View
      final tasks = controller.tasks;
      final summary = controller.dailySummary.value;
      final selectedDate = controller.selectedDate.value;
      final isToday = controller.isToday;

      return Scaffold(
        backgroundColor: AppColors.backgroundLightGreen,
        body: Column(
          children: [
            // 1. Custom Top Navigation Bar with Window Controls
            CustomHeaderBar(
              onOpenSettings: _openSettings,
              onSyncNow: _syncNow,
              onMinimizeToMini: controller.switchToMiniMode,
            ),

            // 2. Scrollable Main Content Area
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // A. Date Navigation Bar (Browse any past date, future disabled)
                        DateNavigationBar(
                          selectedDate: selectedDate,
                          canGoPrevious: controller.canGoPrevious,
                          canGoNext: controller.canGoNext,
                          isToday: isToday,
                          isYesterday: controller.isYesterday,
                          onPreviousDay: controller.previousDay,
                          onNextDay: controller.nextDay,
                          onToday: controller.goToToday,
                          onSelectDate: (dt) => controller.setDate(dt),
                        ),

                        const SizedBox(height: 10),

                        // B. Daily Summary Cards (Total Hours, Billable, Non-Billable, Total Tasks)
                        DailySummaryCards(summary: summary),

                        const SizedBox(height: 12),

                        // C. User can ONLY add task today; rest (past dates) are read-only
                        if (isToday)
                          TaskCreationCard(
                            onTaskAdded: () {
                              controller.loadTasksForSelectedDate();
                            },
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.cardShadow,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.history_rounded, color: Color(0xFFD97706), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Viewing Past Timesheet (${DateFormat('EEEE, MMM d, yyyy').format(selectedDate)}) • Read-Only',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Tasks can only be added and tracked on Today. Historical records are view-only.',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: controller.goToToday,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.today_rounded, size: 15),
                                  label: const Text(
                                    'Switch to Today',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 14),

                        // D. Task List Header
                        Row(
                          children: [
                            Icon(
                              isToday ? Icons.format_list_bulleted_rounded : Icons.history_edu_rounded,
                              size: 18,
                              color: isToday ? AppColors.primaryGreen : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isToday ? 'Today\'s Tasks' : 'Recorded Tasks',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${DateFormat('MMM d, yyyy').format(selectedDate)})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isToday ? AppColors.primaryGreen : const Color(0xFFB45309),
                              ),
                            ),
                            if (!isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'READ-ONLY',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // E. Tasks List Cards
                        if (tasks.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isToday ? AppColors.primaryGreenLight : const Color(0xFFFEF3C7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isToday ? Icons.timer_outlined : Icons.history_rounded,
                                      size: 22,
                                      color: isToday ? AppColors.primaryGreen : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isToday
                                      ? 'No tasks recorded for today yet'
                                      : 'No tasks were recorded on this date',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isToday
                                      ? 'Select a project and enter a task description above to start tracking your time.'
                                      : 'Past records are view-only. Switch to Today to create and track tasks.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (!isToday) ...[
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: controller.goToToday,
                                    icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                                    label: const Text('Go to Today\'s Tasks'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return TaskCardItem(
                                key: ValueKey(task.id),
                                task: task,
                                index: index,
                                isReadOnly: !isToday,
                                onTaskDeleted: () {
                                  controller.loadTasksForSelectedDate();
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
