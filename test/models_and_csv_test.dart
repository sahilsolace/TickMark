import 'package:flutter_test/flutter_test.dart';
import 'package:tickmark/models/csv_export_row.dart';
import 'package:tickmark/models/daily_summary_model.dart';
import 'package:tickmark/models/task_model.dart';
import 'package:tickmark/services/csv_export_service.dart';

void main() {
  group('CSV Export Tests', () {
    test('Expected CSV Header is exact and in specified order', () {
      expect(
        CsvExportService.csvHeader,
        equals('date,employee_email,project_name,task_description,minutes,billable'),
      );
    });

    test('CsvExportRow formats properly without special characters', () {
      final row = CsvExportRow(
        date: '2026-11-23',
        employeeEmail: 'employee@company.com',
        projectName: 'BAU Farm Intelligence',
        taskDescription: 'Fix authentication issue',
        minutes: 45,
        billable: true,
      );

      expect(
        row.toCsvLine(),
        equals('2026-11-23,employee@company.com,BAU Farm Intelligence,Fix authentication issue,45,true'),
      );
    });

    test('CsvExportRow escapes commas, quotes, and newlines properly (RFC 4180)', () {
      final row = CsvExportRow(
        date: '2026-11-23',
        employeeEmail: 'employee@company.com',
        projectName: 'Project, Special',
        taskDescription: 'Fix "quoted" issue, and commas',
        minutes: 30,
        billable: false,
      );

      expect(
        row.toCsvLine(),
        equals('2026-11-23,employee@company.com,"Project, Special","Fix ""quoted"" issue, and commas",30,false'),
      );
    });

    test('CsvExportService generates valid CSV with UTF-8 BOM', () {
      final rows = [
        CsvExportRow(
          date: '2026-11-23',
          employeeEmail: 'employee@company.com',
          projectName: 'BAU Farm Intelligence',
          taskDescription: 'Fix authentication issue',
          minutes: 45,
          billable: true,
        ),
        CsvExportRow(
          date: '2026-11-23',
          employeeEmail: 'employee@company.com',
          projectName: 'Internal Tasks',
          taskDescription: 'Team meeting',
          minutes: 30,
          billable: false,
        ),
      ];

      final csvContent = CsvExportService.instance.generateCsvString(rows);
      expect(csvContent.startsWith('\uFEFFdate,employee_email,project_name,task_description,minutes,billable'), isTrue);
      expect(csvContent.contains('2026-11-23,employee@company.com,BAU Farm Intelligence,Fix authentication issue,45,true'), isTrue);
      expect(csvContent.contains('2026-11-23,employee@company.com,Internal Tasks,Team meeting,30,false'), isTrue);
    });
  });

  group('TaskModel & Summary Tests', () {
    test('TaskModel formattedDuration shows HH:MM:SS', () {
      final task = TaskModel(
        projectId: 1,
        projectName: 'Test',
        taskDescription: 'Test task',
        workDate: '2026-11-23',
        createdAt: '',
        updatedAt: '',
        totalDurationSeconds: 3665, // 1 hr, 1 min, 5 sec
      );

      expect(task.formattedDuration, equals('01:01:05'));
    });

    test('DailySummaryModel format seconds correctly', () {
      final summary = DailySummaryModel(
        workDate: '2026-11-23',
        totalSeconds: 5400, // 1h 30m
        billableSeconds: 3600, // 1h
        nonBillableSeconds: 1800, // 30m
        totalTasks: 2,
      );

      expect(summary.formattedTotalHours, equals('01:30:00'));
      expect(summary.formattedBillableHours, equals('01:00:00'));
      expect(summary.formattedNonBillableHours, equals('00:30:00'));
      expect(summary.totalTasks, equals(2));
    });
  });
}
