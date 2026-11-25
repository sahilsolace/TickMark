import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class DateNavigationBar extends StatelessWidget {
  final DateTime selectedDate;
  final bool canGoPrevious;
  final bool canGoNext;
  final bool isToday;
  final bool isYesterday;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelectDate;

  const DateNavigationBar({
    super.key,
    required this.selectedDate,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.isToday,
    required this.isYesterday,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onToday,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEE, MMM d, yyyy').format(selectedDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String badgeText;
    Color badgeBg;
    Color badgeTextColor;

    if (isToday) {
      badgeText = 'TODAY';
      badgeBg = AppColors.primaryGreenLight;
      badgeTextColor = AppColors.primaryGreen;
    } else if (isYesterday) {
      badgeText = 'YESTERDAY';
      badgeBg = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFB45309);
    } else {
      badgeText = 'READ-ONLY';
      badgeBg = const Color(0xFFF3F4F6);
      badgeTextColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous Day Button (Navigate back to see past timesheets)
          IconButton(
            tooltip: 'Previous Day (View Past Timesheet)',
            icon: const Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: AppColors.textPrimary,
            ),
            onPressed: canGoPrevious ? onPreviousDay : null,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              hoverColor: AppColors.primaryGreenLight,
            ),
          ),

          // Date Display & Picker Trigger
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: today,
                  helpText: 'Select Date to View Timesheet',
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.primaryGreen,
                          onPrimary: Colors.white,
                          onSurface: AppColors.textDark,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  onSelectDate(picked);
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isToday ? Icons.calendar_today_outlined : Icons.history_rounded,
                      size: 15,
                      color: isToday ? AppColors.primaryGreen : AppColors.pauseAmber,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isToday ? 'Today • $formattedDate' : formattedDate,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isToday ? AppColors.textPrimary : const Color(0xFF92400E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Next Day Button (Enabled on past dates -> moves forward towards today)
          IconButton(
            tooltip: canGoNext ? 'Next Day' : 'Cannot navigate into future dates',
            icon: Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: canGoNext ? AppColors.textPrimary : AppColors.textMuted,
            ),
            onPressed: canGoNext ? onNextDay : null,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              hoverColor: AppColors.primaryGreenLight,
            ),
          ),

          const SizedBox(width: 6),

          // Today Button
          OutlinedButton(
            onPressed: isToday ? null : onToday,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              backgroundColor: isToday ? AppColors.primaryGreenLight : Colors.transparent,
              side: BorderSide(
                color: isToday ? AppColors.primaryGreen : AppColors.cardBorder,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isToday) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? AppColors.primaryGreen : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
