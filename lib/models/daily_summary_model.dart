class DailySummaryModel {
  final String workDate;
  final int totalSeconds;
  final int billableSeconds;
  final int nonBillableSeconds;
  final int totalTasks;

  DailySummaryModel({
    required this.workDate,
    required this.totalSeconds,
    required this.billableSeconds,
    required this.nonBillableSeconds,
    required this.totalTasks,
  });

  factory DailySummaryModel.empty(String date) {
    return DailySummaryModel(
      workDate: date,
      totalSeconds: 0,
      billableSeconds: 0,
      nonBillableSeconds: 0,
      totalTasks: 0,
    );
  }

  static String formatSecondsToHMS(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String formatSecondsToFriendlyHours(int seconds) {
    if (seconds <= 0) return '0h 0m';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours == 0) {
      return '${minutes}m';
    }
    return '${hours}h ${minutes}m';
  }

  String get formattedTotalHours => formatSecondsToHMS(totalSeconds);
  String get formattedBillableHours => formatSecondsToHMS(billableSeconds);
  String get formattedNonBillableHours => formatSecondsToHMS(nonBillableSeconds);
}
