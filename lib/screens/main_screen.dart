import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';
import '../services/time_tracking_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_header_bar.dart';
import '../widgets/date_navigation_bar.dart';
import '../widgets/daily_summary_cards.dart';
import '../widgets/task_creation_card.dart';
import '../widgets/task_card_item.dart';
import '../widgets/export_csv_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/mini_tracker_widget.dart';

enum AppViewMode {
  full,
  mini,
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  final TimeTrackingService _timeService = TimeTrackingService();
  final ScrollController _scrollController = ScrollController();

  AppViewMode _viewMode = AppViewMode.full;
  Size _savedFullSize = const Size(840, 680);
  Offset? _savedFullPosition;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _timeService.initialize();
    _checkInitialWindowSize();
  }

  Future<void> _checkInitialWindowSize() async {
    try {
      final size = await windowManager.getSize();
      if (size.width < 500 && mounted) {
        setState(() {
          _viewMode = AppViewMode.mini;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Gracefully persist any active timer before closing
    await _timeService.handleAppClosing();
    await windowManager.destroy();
  }

  Future<void> _switchToMiniMode() async {
    try {
      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      // Only save if currently in full mode
      if (_viewMode == AppViewMode.full && size.width > 500) {
        _savedFullSize = size;
        _savedFullPosition = pos;
      }

      await windowManager.setMinimumSize(const Size(320, 130));
      await windowManager.setMaximumSize(const Size(480, 180));
      await windowManager.setSize(const Size(380, 140));
      await windowManager.setAlwaysOnTop(true);
    } catch (e) {
      debugPrint('Error transitioning to mini mode: $e');
    }

    setState(() {
      _viewMode = AppViewMode.mini;
    });
  }

  Future<void> _switchToFullMode() async {
    try {
      await windowManager.setMaximumSize(const Size(3840, 2160));
      await windowManager.setMinimumSize(const Size(600, 480));
      await windowManager.setSize(_savedFullSize);
      if (_savedFullPosition != null) {
        await windowManager.setPosition(_savedFullPosition!);
      }
      await windowManager.setAlwaysOnTop(false);
    } catch (e) {
      debugPrint('Error transitioning to full mode: $e');
    }

    setState(() {
      _viewMode = AppViewMode.full;
    });
  }

  void _openSettings() {
    SettingsDialog.show(context);
  }

  void _openExport() {
    ExportCsvDialog.show(context, _timeService.selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _timeService,
      builder: (context, _) {
        // If in Mini Tracker Mode: show ONLY the current ongoing task
        if (_viewMode == AppViewMode.mini) {
          return MiniTrackerWidget(
            onExpandToFull: _switchToFullMode,
          );
        }

        // Full Application View
        final tasks = _timeService.tasks;
        final summary = _timeService.dailySummary;
        final selectedDate = _timeService.selectedDate;
        final isToday = _timeService.isToday;

        return Scaffold(
          backgroundColor: AppColors.backgroundLightGreen,
          body: Column(
            children: [
              // 1. Custom Top Navigation Bar with Window Controls
              CustomHeaderBar(
                onOpenSettings: _openSettings,
                onExportCsv: _openExport,
                onMinimizeToMini: _switchToMiniMode,
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
                            canGoPrevious: _timeService.canGoPrevious,
                            canGoNext: _timeService.canGoNext,
                            isToday: isToday,
                            isYesterday: _timeService.isYesterday,
                            onPreviousDay: _timeService.previousDay,
                            onNextDay: _timeService.nextDay,
                            onToday: _timeService.goToToday,
                            onSelectDate: (dt) => _timeService.setDate(dt),
                          ),

                          const SizedBox(height: 10),

                          // B. Daily Summary Cards (Total Hours, Billable, Non-Billable, Total Tasks)
                          DailySummaryCards(summary: summary),

                          const SizedBox(height: 12),

                          // C. User can ONLY add task today; rest (past dates) are read-only
                          if (isToday)
                            TaskCreationCard(
                              onTaskAdded: () {
                                _timeService.loadTasksForSelectedDate();
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
                                    onPressed: _timeService.goToToday,
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
                                border: Border.all(color: AppColors.cardBorder),
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
                                      onPressed: _timeService.goToToday,
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
                                    _timeService.loadTasksForSelectedDate();
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
      },
    );
  }
}

