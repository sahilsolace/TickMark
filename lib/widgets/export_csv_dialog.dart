import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/csv_export_row.dart';
import '../services/csv_export_service.dart';
import '../theme/app_colors.dart';

class ExportCsvDialog extends StatefulWidget {
  final DateTime initialSelectedDate;

  const ExportCsvDialog({
    super.key,
    required this.initialSelectedDate,
  });

  static Future<void> show(BuildContext context, DateTime selectedDate) {
    return showDialog<void>(
      context: context,
      builder: (context) => ExportCsvDialog(initialSelectedDate: selectedDate),
    );
  }

  @override
  State<ExportCsvDialog> createState() => _ExportCsvDialogState();
}

class _ExportCsvDialogState extends State<ExportCsvDialog> {
  final _exportService = CsvExportService.instance;

  late ExportScope _scope;
  late DateTime _startDate;
  late DateTime _endDate;

  bool _isExporting = false;
  bool _isLoadingPreview = false;
  List<CsvExportRow> _previewRows = [];
  String? _statusMessage;
  bool _isSuccess = false;
  String? _exportedFilePath;

  @override
  void initState() {
    super.initState();
    _scope = ExportScope.selectedDay;
    _startDate = widget.initialSelectedDate;
    _endDate = widget.initialSelectedDate;
    _loadPreview();
  }

  String _formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  Future<void> _loadPreview() async {
    setState(() => _isLoadingPreview = true);

    try {
      final rows = await _exportService.fetchRows(
        scope: _scope,
        singleDate: _scope == ExportScope.selectedDay ? _formatDate(widget.initialSelectedDate) : null,
        startDate: _scope == ExportScope.customRange ? _formatDate(_startDate) : null,
        endDate: _scope == ExportScope.customRange ? _formatDate(_endDate) : null,
      );

      setState(() {
        _previewRows = rows;
      });
    } catch (e) {
      debugPrint('Error loading preview: $e');
    } finally {
      setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _performExport() async {
    setState(() {
      _isExporting = true;
      _statusMessage = null;
      _isSuccess = false;
      _exportedFilePath = null;
    });

    final singleDate = _scope == ExportScope.selectedDay ? _formatDate(widget.initialSelectedDate) : null;
    final start = _scope == ExportScope.customRange ? _formatDate(_startDate) : null;
    final end = _scope == ExportScope.customRange ? _formatDate(_endDate) : null;

    final result = await _exportService.exportToCsv(
      scope: _scope,
      singleDate: singleDate,
      startDate: start,
      endDate: end,
    );

    setState(() {
      _isExporting = false;
      if (result.success) {
        _isSuccess = true;
        _exportedFilePath = result.filePath;
        _statusMessage = 'Successfully exported ${result.rowCount} records!';
      } else {
        _isSuccess = false;
        _statusMessage = result.errorMessage ?? 'Export failed';
      }
    });
  }

  void _openExportedFileLocation() {
    if (_exportedFilePath != null && Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', _exportedFilePath!]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.file_download_outlined, color: AppColors.primaryGreen, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export Timesheet to CSV',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              SizedBox(height: 2),
              Text(
                'Download detailed date-wise timesheet records',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 12),

            // Export Scope Selection
            const Text(
              'Select Export Scope:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _buildScopeRadio(
                  title: "Selected Day (${_formatDate(widget.initialSelectedDate)})",
                  value: ExportScope.selectedDay,
                ),
                const SizedBox(width: 10),
                _buildScopeRadio(
                  title: 'Date Range',
                  value: ExportScope.customRange,
                ),
                const SizedBox(width: 10),
                _buildScopeRadio(
                  title: 'All Records',
                  value: ExportScope.allRecords,
                ),
              ],
            ),

            // Date Range Pickers (shown if customRange selected)
            if (_scope == ExportScope.customRange) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLightGreen,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() => _startDate = picked);
                                _loadPreview();
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(_formatDate(_startDate), style: const TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: _startDate,
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() => _endDate = picked);
                                _loadPreview();
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(_formatDate(_endDate), style: const TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // CSV Preview Info
            Row(
              children: [
                const Icon(Icons.table_chart_outlined, size: 16, color: AppColors.primaryGreen),
                const SizedBox(width: 6),
                const Text(
                  'CSV Headers & Records Preview',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_previewRows.length} record(s)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Exact CSV Headers info box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'Headers: date, employee_email, project_name, task_description, minutes, billable',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),

            // Records List Preview
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: _isLoadingPreview
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
                  : _previewRows.isEmpty
                      ? const Center(
                          child: Text(
                            'No records found for the selected scope.\nAn empty CSV with headers will still be generated.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _previewRows.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final row = _previewRows[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                children: [
                                  Text(
                                    row.date,
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      row.projectName,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      row.taskDescription,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${row.minutes} min',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: row.billable ? AppColors.billableBg : AppColors.nonBillableBg,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      row.billable ? 'true' : 'false',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: row.billable ? AppColors.billableGreen : AppColors.nonBillableGray,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Success or Error banner
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isSuccess ? AppColors.billableBg : AppColors.deleteBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                      size: 16,
                      color: _isSuccess ? AppColors.primaryGreen : AppColors.deleteRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isSuccess ? AppColors.primaryGreen : AppColors.deleteRed,
                        ),
                      ),
                    ),
                    if (_isSuccess && _exportedFilePath != null)
                      TextButton.icon(
                        onPressed: _openExportedFileLocation,
                        icon: const Icon(Icons.folder_open, size: 14),
                        label: const Text('Open Folder', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed: _isExporting ? null : _performExport,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          icon: _isExporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(_isExporting ? 'Exporting...' : 'Export CSV'),
        ),
      ],
    );
  }

  Widget _buildScopeRadio({
    required String title,
    required ExportScope value,
  }) {
    final isSelected = _scope == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _scope = value);
          _loadPreview();
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreenLight : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.primaryGreen : AppColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 15,
                color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppColors.primaryGreen : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
