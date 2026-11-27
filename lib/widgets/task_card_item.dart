import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/time_tracking_controller.dart';
import '../models/task_model.dart';
import '../theme/app_colors.dart';

class TaskCardItem extends StatelessWidget {
  final TaskModel task;
  final int index;
  final bool isReadOnly;
  final VoidCallback onTaskDeleted;

  const TaskCardItem({
    super.key,
    required this.task,
    required this.index,
    this.isReadOnly = false,
    required this.onTaskDeleted,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.deleteBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.deleteRed, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Delete Task',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete task #${index + 1}?',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLightGreen,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  task.taskDescription,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will permanently delete this task and all its recorded tracking sessions.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deleteRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && task.id != null) {
      final timeController = Get.isRegistered<TimeTrackingController>()
          ? Get.find<TimeTrackingController>()
          : Get.put<TimeTrackingController>(TimeTrackingController());
      await timeController.deleteTask(task.id!);
      onTaskDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeController = Get.isRegistered<TimeTrackingController>()
        ? Get.find<TimeTrackingController>()
        : Get.put<TimeTrackingController>(TimeTrackingController());
    final isRunning = task.isRunning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isRunning ? AppColors.primaryGreen : AppColors.cardBorder,
          width: isRunning ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isRunning
                ? AppColors.primaryGreen.withValues(alpha: 0.12)
                : AppColors.cardShadow,
            blurRadius: isRunning ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 520;

          // Index Badge widget
          final indexBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isRunning ? AppColors.primaryGreenLight : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isRunning ? AppColors.primaryGreen.withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Text(
              '#${index + 1}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isRunning ? AppColors.primaryGreen : AppColors.textSecondary,
              ),
            ),
          );

          // Meta chips (Project & Billable) using Wrap so they never overflow
          final metaChips = Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Project chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_outlined, size: 11, color: AppColors.primaryGreen),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        task.projectName.isNotEmpty ? task.projectName : 'General',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryGreen,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Billable pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: task.billable ? AppColors.billableBg : AppColors.nonBillableBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      task.billable ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked_rounded,
                      size: 10,
                      color: task.billable ? AppColors.billableGreen : AppColors.nonBillableGray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.billable ? 'Billable' : 'Non-billable',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: task.billable ? AppColors.billableGreen : AppColors.nonBillableGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          // Elapsed Time Display
          final timerDisplay = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isRunning ? AppColors.primaryGreenLight : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isRunning ? AppColors.primaryGreen.withValues(alpha: 0.3) : AppColors.cardBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRunning) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  task.formattedDuration,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                    color: isRunning ? AppColors.primaryGreen : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );

          // Action Buttons Group
          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isReadOnly)
                Tooltip(
                  message: 'Tasks and timers can only be run on Today',
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.lock_clock_outlined, color: AppColors.textMuted, size: 20),
                  ),
                )
              else if (!isRunning)
                IconButton(
                  tooltip: task.totalDurationSeconds > 0 ? 'Resume' : 'Play',
                  icon: const Icon(Icons.play_arrow_rounded, color: AppColors.playGreen, size: 22),
                  onPressed: () => timeController.startOrResumeTimer(task),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.playBg,
                    hoverColor: AppColors.primaryGreen.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Pause',
                  icon: const Icon(Icons.pause_rounded, color: AppColors.pauseAmber, size: 22),
                  onPressed: () => timeController.pauseActiveTimer(),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.pauseBg,
                    hoverColor: AppColors.pauseAmber.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                ),

              const SizedBox(width: 6),

              // Stop Button
              IconButton(
                tooltip: 'Stop Session',
                icon: const Icon(Icons.stop_rounded, color: AppColors.stopGray, size: 20),
                onPressed: (isRunning && !isReadOnly) ? () => timeController.stopTimer(task.id!) : null,
                style: IconButton.styleFrom(
                  backgroundColor: isRunning ? AppColors.stopBg : const Color(0xFFF3F4F6),
                  disabledBackgroundColor: const Color(0xFFF3F4F6),
                  hoverColor: AppColors.stopGray.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
              ),

              const SizedBox(width: 6),

              // Delete Button
              IconButton(
                tooltip: 'Delete Task',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary, size: 19),
                onPressed: () => _confirmDelete(context),
                hoverColor: AppColors.deleteBg,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
              ),
            ],
          );

          if (isCompact) {
            // Stacked 2-row layout for compact / narrow widths
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    indexBadge,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.taskDescription,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isRunning ? AppColors.primaryGreen : AppColors.textDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          metaChips,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    timerDisplay,
                    actionButtons,
                  ],
                ),
              ],
            );
          }

          // Full horizontal layout
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              indexBadge,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.taskDescription,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isRunning ? AppColors.primaryGreen : AppColors.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    metaChips,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              timerDisplay,
              const SizedBox(width: 10),
              actionButtons,
            ],
          );
        },
      ),
    );
  }
}
