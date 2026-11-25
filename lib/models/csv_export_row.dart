class CsvExportRow {
  final String date;
  final String employeeEmail;
  final String projectName;
  final String taskDescription;
  final int minutes;
  final bool billable;

  CsvExportRow({
    required this.date,
    required this.employeeEmail,
    required this.projectName,
    required this.taskDescription,
    required this.minutes,
    required this.billable,
  });

  /// Formats row according to RFC 4180
  String toCsvLine() {
    return '${_escape(date)},${_escape(employeeEmail)},${_escape(projectName)},${_escape(taskDescription)},$minutes,$billable';
  }

  static String _escape(String input) {
    if (input.contains(',') || input.contains('"') || input.contains('\n') || input.contains('\r')) {
      final escaped = input.replaceAll('"', '""');
      return '"$escaped"';
    }
    return input;
  }
}
