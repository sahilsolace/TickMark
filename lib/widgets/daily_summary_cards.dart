import 'package:flutter/material.dart';
import '../models/daily_summary_model.dart';
import '../theme/app_colors.dart';

class DailySummaryCards extends StatelessWidget {
  final DailySummaryModel summary;

  const DailySummaryCards({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;

        final cardTotal = _SummaryCard(
          title: 'Total Hours',
          value: summary.formattedTotalHours,
          subText: DailySummaryModel.formatSecondsToFriendlyHours(summary.totalSeconds),
          icon: Icons.access_time_rounded,
          iconColor: AppColors.primaryGreen,
          iconBgColor: AppColors.primaryGreenLight,
        );

        final cardBillable = _SummaryCard(
          title: 'Billable Hours',
          value: summary.formattedBillableHours,
          subText: DailySummaryModel.formatSecondsToFriendlyHours(summary.billableSeconds),
          icon: Icons.monetization_on_outlined,
          iconColor: AppColors.billableGreen,
          iconBgColor: AppColors.billableBg,
        );

        final cardNonBillable = _SummaryCard(
          title: 'Non-Billable',
          value: summary.formattedNonBillableHours,
          subText: DailySummaryModel.formatSecondsToFriendlyHours(summary.nonBillableSeconds),
          icon: Icons.hourglass_empty_rounded,
          iconColor: AppColors.nonBillableGray,
          iconBgColor: AppColors.nonBillableBg,
        );

        final cardTasks = _SummaryCard(
          title: 'Total Tasks',
          value: '${summary.totalTasks}',
          subText: summary.totalTasks == 1 ? '1 task' : '${summary.totalTasks} tasks',
          icon: Icons.task_alt_rounded,
          iconColor: const Color(0xFF2563EB),
          iconBgColor: const Color(0xFFEFF6FF),
        );

        if (isNarrow) {
          // 2x2 Grid for compact widths
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cardTotal),
                  const SizedBox(width: 10),
                  Expanded(child: cardBillable),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: cardNonBillable),
                  const SizedBox(width: 10),
                  Expanded(child: cardTasks),
                ],
              ),
            ],
          );
        }

        // Full 4-card horizontal row
        return Row(
          children: [
            Expanded(child: cardTotal),
            const SizedBox(width: 10),
            Expanded(child: cardBillable),
            const SizedBox(width: 10),
            Expanded(child: cardNonBillable),
            const SizedBox(width: 10),
            Expanded(child: cardTasks),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subText;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subText,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Icon(icon, size: 15, color: iconColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subText,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
