import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/csv_export_row.dart';

enum ExportScope {
  selectedDay,
  customRange,
  allRecords,
}

class ExportResult {
  final bool success;
  final String? filePath;
  final int rowCount;
  final String? errorMessage;

  ExportResult({
    required this.success,
    this.filePath,
    this.rowCount = 0,
    this.errorMessage,
  });
}

class CsvExportService {
  static final CsvExportService instance = CsvExportService._internal();
  factory CsvExportService() => instance;
  CsvExportService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  static const String csvHeader = 'date,employee_email,project_name,task_description,minutes,billable';

  /// Generates the CSV string content from a list of rows.
  /// Follows exact requirements and RFC 4180.
  String generateCsvString(List<CsvExportRow> rows) {
    final buffer = StringBuffer();
    // UTF-8 BOM so Microsoft Excel cleanly opens UTF-8 encoded files
    buffer.write('\uFEFF');
    buffer.writeln(csvHeader);

    for (final row in rows) {
      buffer.writeln(row.toCsvLine());
    }

    return buffer.toString();
  }

  /// Fetches export data based on scope and parameters.
  Future<List<CsvExportRow>> fetchRows({
    required ExportScope scope,
    String? singleDate,
    String? startDate,
    String? endDate,
  }) async {
    switch (scope) {
      case ExportScope.selectedDay:
        return await _dbHelper.getCsvExportData(singleDate: singleDate);
      case ExportScope.customRange:
        return await _dbHelper.getCsvExportData(startDate: startDate, endDate: endDate);
      case ExportScope.allRecords:
        return await _dbHelper.getCsvExportData();
    }
  }

  /// Exports data to a CSV file.
  /// Prompts user with native desktop save dialog.
  Future<ExportResult> exportToCsv({
    required ExportScope scope,
    String? singleDate,
    String? startDate,
    String? endDate,
    String? customFileName,
  }) async {
    try {
      final rows = await fetchRows(
        scope: scope,
        singleDate: singleDate,
        startDate: startDate,
        endDate: endDate,
      );

      final csvContent = generateCsvString(rows);

      // Determine default filename
      String fileName;
      if (customFileName != null && customFileName.isNotEmpty) {
        fileName = customFileName.endsWith('.csv') ? customFileName : '$customFileName.csv';
      } else {
        switch (scope) {
          case ExportScope.selectedDay:
            fileName = 'TickMark_Timesheet_${singleDate ?? "Day"}.csv';
            break;
          case ExportScope.customRange:
            fileName = 'TickMark_Timesheet_${startDate ?? "start"}_to_${endDate ?? "end"}.csv';
            break;
          case ExportScope.allRecords:
            final today = DateTime.now().toIso8601String().substring(0, 10);
            fileName = 'TickMark_Timesheet_All_Records_$today.csv';
            break;
        }
      }

      // Open native save dialog using FilePicker.saveFile
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      Uri? saveUri;
      try {
        saveUri = await FilePicker.saveFile(
          dialogTitle: 'Export Timesheet to CSV',
          fileName: fileName,
          bytes: bytes,
        );
      } catch (e) {
        debugPrint('FilePicker error: $e, falling back to Downloads folder');
      }

      // If user cancelled save dialog
      if (saveUri == null) {
        return ExportResult(
          success: false,
          errorMessage: 'Export cancelled by user',
        );
      }

      String savePath = saveUri.toFilePath();

      return ExportResult(
        success: true,
        filePath: savePath,
        rowCount: rows.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Fallback: saves directly into user's Downloads directory if dialog is bypassed
  Future<ExportResult> exportToDownloads({
    required ExportScope scope,
    String? singleDate,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final rows = await fetchRows(
        scope: scope,
        singleDate: singleDate,
        startDate: startDate,
        endDate: endDate,
      );

      final csvContent = generateCsvString(rows);

      String fileName;
      switch (scope) {
        case ExportScope.selectedDay:
          fileName = 'TickMark_Timesheet_${singleDate ?? "Day"}.csv';
          break;
        case ExportScope.customRange:
          fileName = 'TickMark_Timesheet_${startDate ?? "start"}_to_${endDate ?? "end"}.csv';
          break;
        case ExportScope.allRecords:
          final today = DateTime.now().toIso8601String().substring(0, 10);
          fileName = 'TickMark_Timesheet_All_Records_$today.csv';
          break;
      }

      Directory? downloadsDir = await getDownloadsDirectory();
      downloadsDir ??= await getApplicationDocumentsDirectory();

      final targetPath = p.join(downloadsDir.path, fileName);
      final file = File(targetPath);
      await file.writeAsString(csvContent, flush: true);

      return ExportResult(
        success: true,
        filePath: targetPath,
        rowCount: rows.length,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}
