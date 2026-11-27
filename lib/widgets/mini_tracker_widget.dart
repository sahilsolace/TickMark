import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../models/task_model.dart';
import '../services/time_tracking_service.dart';
import '../theme/app_colors.dart';

class MiniTrackerWidget extends StatelessWidget {
  final VoidCallback onExpandToFull;

  const MiniTrackerWidget({
    super.key,
    required this.onExpandToFull,
  });

  TaskModel? _getOngoingOrLastTask(TimeTrackingService service) {
    if (service.tasks.isEmpty) return null;

    // 1. If there's an active running task, return it
    if (service.activeTaskId != null) {
      final running = service.tasks.where((t) => t.id == service.activeTaskId);
      if (running.isNotEmpty) return running.first;
    }

    // 2. Otherwise return the task with the most recent tracked time
    final tracked = service.tasks.where((t) => t.totalDurationSeconds > 0).toList();
    if (tracked.isNotEmpty) {
      tracked.sort((a, b) => b.totalDurationSeconds.compareTo(a.totalDurationSeconds));
      return tracked.first;
    }

    // 3. Fallback to first task
    return service.tasks.first;
  }

  @override
  Widget build(BuildContext context) {
    final service = TimeTrackingService();
    final ongoingTask = _getOngoingOrLastTask(service);
    final isRunning = ongoingTask != null && ongoingTask.isRunning;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DragToResizeArea(
        resizeEdgeSize: 8,
        child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRunning ? AppColors.primaryGreen : AppColors.cardBorder,
            width: isRunning ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isRunning
                  ? AppColors.primaryGreen.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Draggable Mini Header
            DragToMoveArea(
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  color: AppColors.backgroundLightGreen,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                  border: Border(
                    bottom: BorderSide(color: AppColors.headerBorder, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    // Small App Icon
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Icon(Icons.check_rounded, color: Colors.white, size: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'TickMark',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Live Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isRunning ? AppColors.billableBg : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isRunning ? AppColors.primaryGreen : AppColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isRunning ? 'TRACKING' : (ongoingTask != null && ongoingTask.totalDurationSeconds > 0 ? 'PAUSED' : 'IDLE'),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isRunning ? AppColors.primaryGreen : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Expand to Full App Button
                    IconButton(
                      tooltip: 'Expand to Full Application',
                      icon: const Icon(Icons.open_in_full_rounded, size: 14, color: AppColors.primaryGreen),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: onExpandToFull,
                    ),

                    // Minimize to Taskbar
                    IconButton(
                      tooltip: 'Minimize to Taskbar',
                      icon: const Icon(Icons.remove, size: 14, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () => windowManager.minimize(),
                    ),

                    // Close Window
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () => windowManager.close(),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Ongoing Task Body
            Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: ongoingTask != null
                      ? Row(
                          children: [
                            // Task details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Task title
                                  Text(
                                    ongoingTask.taskDescription,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isRunning ? AppColors.primaryGreen : AppColors.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  // Project chip & Billable tag
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGreenLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          ongoingTask.projectName.isNotEmpty ? ongoingTask.projectName : 'General',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryGreen,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (ongoingTask.billable)
                                        const Text(
                                          '• Billable',
                                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),

                            // Timer display & controls
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Large Monospace Timer
                                Text(
                                  ongoingTask.formattedDuration,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: isRunning ? AppColors.primaryGreen : AppColors.textPrimary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Controls: Play/Pause and Stop
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isRunning)
                                      InkWell(
                                        onTap: () => service.startOrResumeTimer(ongoingTask),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: AppColors.playBg,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Icon(Icons.play_arrow_rounded, color: AppColors.playGreen, size: 16),
                                        ),
                                      )
                                    else
                                      InkWell(
                                        onTap: () => service.pauseActiveTimer(),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: AppColors.pauseBg,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Icon(Icons.pause_rounded, color: AppColors.pauseAmber, size: 16),
                                        ),
                                      ),

                                    const SizedBox(width: 4),

                                    InkWell(
                                      onTap: isRunning ? () => service.stopTimer(ongoingTask.id!) : null,
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: isRunning ? AppColors.stopBg : const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Icon(
                                          Icons.stop_rounded,
                                          color: isRunning ? AppColors.stopGray : AppColors.textMuted,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'No task currently tracked.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: onExpandToFull,
                              icon: const Icon(Icons.open_in_full_rounded, size: 13),
                              label: const Text('Open App', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}