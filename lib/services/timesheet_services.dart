import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:tickmark/controllers/timesheet_controller.dart';
import 'package:tickmark/database/database_helper.dart';
import 'package:tickmark/models/project_model.dart';
import 'package:tickmark/services/app_const.dart';
import 'package:tickmark/services/auth_service.dart';

class TimesheetServices {
  /// Fetches projects from the API, saves them into local SQLite,
  /// and updates the [TimesheetController] projects list.
  /// Falls back to local SQLite projects if offline.
  static Future<List<ProjectModel>> getProject() async {
    final timesheetController = Get.isRegistered<TimesheetController>()
        ? Get.find<TimesheetController>()
        : Get.put(TimesheetController());

    try {
      final token = await AuthService.getToken();

      final response = await http.get(
        Uri.parse('${AppConst.baseUrl}/projects.php'),
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<ProjectModel> projectList = [];

        if (decoded is List) {
          projectList = decoded
              .map((item) => ProjectModel.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) {
            projectList = (decoded['data'] as List)
                .map((item) => ProjectModel.fromJson(item as Map<String, dynamic>))
                .toList();
          } else if (decoded['projects'] is List) {
            projectList = (decoded['projects'] as List)
                .map((item) => ProjectModel.fromJson(item as Map<String, dynamic>))
                .toList();
          } else if (decoded['success'] == true && decoded['data'] is List) {
            projectList = (decoded['data'] as List)
                .map((item) => ProjectModel.fromJson(item as Map<String, dynamic>))
                .toList();
          } else {
            projectList = [ProjectModel.fromJson(decoded)];
          }
        }

        // Cache projects in local SQLite database
        if (projectList.isNotEmpty) {
          await DatabaseHelper.instance.upsertProjects(projectList);
        }

        timesheetController.projects.assignAll(projectList);
        return projectList;
      } else {
        debugPrint('Failed to fetch projects from API (Code: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('TimesheetServices getProject network error: $e');
    }

    // Fallback: load cached projects from SQLite database
    final localProjects = await DatabaseHelper.instance.getProjects(includeArchived: false);
    timesheetController.projects.assignAll(localProjects);
    return localProjects;
  }

  /// Syncs date-wise timesheet tasks to the remote API.
  /// Endpoint: http://localhost/timesheet-manager/api/v1/timesheets/sync.php
  /// Payload schema:
  /// {
  ///   "date": "YYYY-MM-DD",
  ///   "entries": [
  ///     {
  ///       "client_entry_id": "4",
  ///       "project_id": 1,
  ///       "task_description": "...",
  ///       "minutes": 120,
  ///       "billable": true
  ///     }
  ///   ]
  /// }
  static Future<bool> syncTimesheet({required String date}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        Get.snackbar(
          'Authentication Required',
          'Please sign in to sync timesheets with the server.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.amber.shade100,
          colorText: Colors.amber.shade900,
          margin: const EdgeInsets.all(12),
        );
        return false;
      }

      // 1. Fetch all tasks recorded for this date
      final dbTasks = await DatabaseHelper.instance.getTasksForDate(date);

      if (dbTasks.isEmpty) {
        Get.snackbar(
          'Nothing to Sync',
          'No task records found for $date.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFF3F4F6),
          colorText: Colors.black87,
          margin: const EdgeInsets.all(12),
        );
        return false;
      }

      // 2. Map tasks to the required entries schema
      final entries = dbTasks.map((task) {
        int minutes = (task.totalDurationSeconds / 60.0).round();
        if (minutes == 0 && task.totalDurationSeconds > 0) {
          minutes = 1;
        }

        return {
          'client_entry_id': '${task.id ?? ''}',
          'project_id': task.projectId,
          'task_description': task.taskDescription,
          'minutes': minutes,
          'billable': task.billable,
        };
      }).toList();

      // 3. Assemble JSON payload
      final payload = {
        'date': date,
        'entries': entries,
      };

      final syncUrl = Uri.parse('${AppConst.baseUrl}/timesheets/sync.php');

      debugPrint('Syncing timesheet to $syncUrl for date: $date (${entries.length} entries)');

      final response = await http.post(
        syncUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Sync response status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        String successMessage = 'Successfully synced ${entries.length} task(s) for $date';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            successMessage = data['message'].toString();
          }
        } catch (_) {}

        Get.snackbar(
          'Sync Completed',
          successMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFE8F7E9),
          colorText: const Color(0xFF087A3D),
          icon: const Icon(Icons.cloud_done_rounded, color: Color(0xFF087A3D)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 4),
        );
        return true;
      } else {
        String errorMessage = 'Server returned HTTP ${response.statusCode}';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) {
            errorMessage = data['message'].toString();
          }
        } catch (_) {}

        Get.snackbar(
          'Sync Failed',
          errorMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900,
          icon: const Icon(Icons.cloud_off_rounded, color: Colors.red),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 4),
        );
        return false;
      }
    } catch (e) {
      debugPrint('TimesheetServices sync error: $e');
      Get.snackbar(
        'Sync Error',
        'Could not reach server: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        icon: const Icon(Icons.error_outline_rounded, color: Colors.red),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      );
      return false;
    }
  }
}
