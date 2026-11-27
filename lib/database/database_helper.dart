import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/employee_model.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/daily_summary_model.dart';
import '../models/csv_export_row.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static bool _ffiInitialized = false;

  static void initializeFfi() {
    if (_ffiInitialized) return;
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tickmark.db');
    return _database!;
  }

  Future<String> getDatabasePath() async {
    final appDir = await getApplicationSupportDirectory();
    final tickMarkDir = Directory(p.join(appDir.path, 'TickMark'));
    if (!await tickMarkDir.exists()) {
      await tickMarkDir.create(recursive: true);
    }
    return p.join(tickMarkDir.path, 'tickmark.db');
  }

  Future<Database> _initDB(String filePath) async {
    initializeFfi();
    final dbPath = await getDatabasePath();

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createDB,
      onOpen: _onOpenDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    // 1. Employees table
    await db.execute('''
      CREATE TABLE employees (
        id $idType,
        employee_email $textType,
        employee_name TEXT,
        created_at $textType,
        updated_at $textType
      )
    ''');

    // 2. Projects table
    await db.execute('''
      CREATE TABLE projects (
        id $idType,
        project_name $textType UNIQUE,
        is_archived $intType DEFAULT 0,
        created_at $textType,
        updated_at $textType
      )
    ''');

    // 3. Tasks table
    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        project_id $intType,
        task_description $textType,
        billable $intType DEFAULT 1,
        work_date $textType,
        created_at $textType,
        updated_at $textType,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    // 4. Time Entries table
    await db.execute('''
      CREATE TABLE time_entries (
        id $idType,
        task_id $intType,
        employee_id $intType,
        start_timestamp $textType,
        end_timestamp TEXT,
        duration_seconds $intType DEFAULT 0,
        work_date $textType,
        is_active $intType DEFAULT 0,
        created_at $textType,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
        FOREIGN KEY (employee_id) REFERENCES employees(id)
      )
    ''');

    // Indices for high performance date & task lookups
    await db.execute('CREATE INDEX idx_tasks_work_date ON tasks(work_date);');
    await db.execute('CREATE INDEX idx_time_entries_task_id ON time_entries(task_id);');
    await db.execute('CREATE INDEX idx_time_entries_work_date ON time_entries(work_date);');

    // Seed initial data
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Default Employee
    await db.insert('employees', {
      'employee_email': 'employee@company.com',
      'employee_name': 'Employee',
      'created_at': now,
      'updated_at': now,
    });

    // Default Projects
    final initialProjects = [

    ];

    for (final proj in initialProjects) {
      await db.insert('projects', {
        'project_name': proj,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<void> _onOpenDB(Database db) async {
    // Crash recovery: check for any active unclosed sessions and close them safely
    try {
      final activeEntries = await db.query(
        'time_entries',
        where: 'is_active = 1 OR end_timestamp IS NULL',
      );

      final now = DateTime.now();
      for (final row in activeEntries) {
        final id = row['id'] as int;
        final startStr = row['start_timestamp'] as String;
        final start = DateTime.tryParse(startStr) ?? now;
        final duration = now.difference(start).inSeconds;
        // Cap reasonably if it was left open across days/hours
        final validDuration = duration > 0 ? duration : 0;

        await db.update(
          'time_entries',
          {
            'end_timestamp': now.toIso8601String(),
            'duration_seconds': validDuration,
            'is_active': 0,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } catch (e) {
      debugPrint('Crash recovery note: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // EMPLOYEE METHODS
  // ---------------------------------------------------------------------------

  Future<EmployeeModel> getEmployee() async {
    final db = await instance.database;
    final results = await db.query('employees', limit: 1);
    if (results.isNotEmpty) {
      return EmployeeModel.fromMap(results.first);
    }
    // Fallback seed
    final now = DateTime.now().toIso8601String();
    final newId = await db.insert('employees', {
      'employee_email': 'employee@company.com',
      'employee_name': 'Employee',
      'created_at': now,
      'updated_at': now,
    });
    return EmployeeModel(
      id: newId,
      employeeEmail: 'employee@company.com',
      employeeName: 'Employee',
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateEmployee(EmployeeModel employee) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'employees',
      {
        'employee_email': employee.employeeEmail.trim(),
        'employee_name': employee.employeeName?.trim(),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [employee.id ?? 1],
    );
  }

  // ---------------------------------------------------------------------------
  // PROJECT METHODS
  // ---------------------------------------------------------------------------

  Future<List<ProjectModel>> getProjects({bool includeArchived = false}) async {
    final db = await instance.database;
    final whereClause = includeArchived ? null : 'is_archived = 0';
    final results = await db.query(
      'projects',
      where: whereClause,
      orderBy: 'project_name COLLATE NOCASE ASC',
    );
    return results.map((m) => ProjectModel.fromMap(m)).toList();
  }

  Future<ProjectModel> addProject(String projectName) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final cleanName = projectName.trim();

    // Check if project exists
    final existing = await db.query(
      'projects',
      where: 'project_name = ? COLLATE NOCASE',
      whereArgs: [cleanName],
    );

    if (existing.isNotEmpty) {
      // If archived, unarchive it
      final row = existing.first;
      if ((row['is_archived'] as int? ?? 0) == 1) {
        await db.update(
          'projects',
          {'is_archived': 0, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      return ProjectModel.fromMap(row).copyWith(isArchived: false);
    }

    final id = await db.insert('projects', {
      'project_name': cleanName,
      'is_archived': 0,
      'created_at': now,
      'updated_at': now,
    });

    return ProjectModel(
      id: id,
      projectName: cleanName,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateProject(int id, String newName) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'projects',
      {'project_name': newName.trim(), 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setProjectArchived(int id, bool archived) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'projects',
      {'is_archived': archived ? 1 : 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // TASK METHODS
  // ---------------------------------------------------------------------------

  Future<List<TaskModel>> getTasksForDate(String workDate) async {
    final db = await instance.database;

    final results = await db.rawQuery('''
      SELECT 
        t.id,
        t.project_id,
        p.project_name,
        t.task_description,
        t.billable,
        t.work_date,
        t.created_at,
        t.updated_at,
        COALESCE(SUM(te.duration_seconds), 0) AS total_duration_seconds
      FROM tasks t
      LEFT JOIN projects p ON t.project_id = p.id
      LEFT JOIN time_entries te ON t.id = te.task_id AND te.work_date = t.work_date
      WHERE t.work_date = ?
      GROUP BY t.id
      ORDER BY t.id ASC
    ''', [workDate]);

    return results.map((m) => TaskModel.fromMap(m)).toList();
  }

  Future<TaskModel> createTask({
    required int projectId,
    required String taskDescription,
    required bool billable,
    required String workDate,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();

    final id = await db.insert('tasks', {
      'project_id': projectId,
      'task_description': taskDescription.trim(),
      'billable': billable ? 1 : 0,
      'work_date': workDate,
      'created_at': now,
      'updated_at': now,
    });

    // Fetch project name
    final projResults = await db.query(
      'projects',
      columns: ['project_name'],
      where: 'id = ?',
      whereArgs: [projectId],
    );
    final projectName = projResults.isNotEmpty ? projResults.first['project_name'] as String : '';

    return TaskModel(
      id: id,
      projectId: projectId,
      projectName: projectName,
      taskDescription: taskDescription.trim(),
      billable: billable,
      workDate: workDate,
      createdAt: now,
      updatedAt: now,
      totalDurationSeconds: 0,
    );
  }

  Future<void> deleteTask(int taskId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('time_entries', where: 'task_id = ?', whereArgs: [taskId]);
      await txn.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
    });
  }

  // ---------------------------------------------------------------------------
  // TIME ENTRY METHODS
  // ---------------------------------------------------------------------------

  Future<int> startTimeEntry({
    required int taskId,
    required int employeeId,
    required String workDate,
    required DateTime startTimestamp,
  }) async {
    final db = await instance.database;
    final startStr = startTimestamp.toIso8601String();

    return await db.insert('time_entries', {
      'task_id': taskId,
      'employee_id': employeeId,
      'start_timestamp': startStr,
      'end_timestamp': null,
      'duration_seconds': 0,
      'work_date': workDate,
      'is_active': 1,
      'created_at': startStr,
    });
  }

  Future<void> stopTimeEntry({
    required int entryId,
    required DateTime endTimestamp,
    required int durationSeconds,
  }) async {
    final db = await instance.database;
    await db.update(
      'time_entries',
      {
        'end_timestamp': endTimestamp.toIso8601String(),
        'duration_seconds': durationSeconds,
        'is_active': 0,
      },
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<void> updateActiveEntryDuration(int entryId, int durationSeconds) async {
    final db = await instance.database;
    await db.update(
      'time_entries',
      {
        'duration_seconds': durationSeconds,
      },
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<void> pauseAllActiveEntries() async {
    final db = await instance.database;
    final activeEntries = await db.query(
      'time_entries',
      where: 'is_active = 1',
    );

    final now = DateTime.now();
    for (final row in activeEntries) {
      final id = row['id'] as int;
      final startStr = row['start_timestamp'] as String;
      final start = DateTime.tryParse(startStr) ?? now;
      final duration = now.difference(start).inSeconds;

      await db.update(
        'time_entries',
        {
          'end_timestamp': now.toIso8601String(),
          'duration_seconds': duration > 0 ? duration : 0,
          'is_active': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DAILY SUMMARY
  // ---------------------------------------------------------------------------

  Future<DailySummaryModel> getDailySummary(String workDate) async {
    final db = await instance.database;

    final results = await db.rawQuery('''
      SELECT
        t.billable,
        COALESCE(SUM(te.duration_seconds), 0) AS total_seconds,
        COUNT(DISTINCT t.id) AS task_count
      FROM tasks t
      LEFT JOIN time_entries te ON t.id = te.task_id AND te.work_date = t.work_date
      WHERE t.work_date = ?
      GROUP BY t.billable
    ''', [workDate]);

    int billableSeconds = 0;
    int nonBillableSeconds = 0;

    for (final row in results) {
      final isBillable = (row['billable'] as int? ?? 1) == 1;
      final seconds = row['total_seconds'] as int? ?? 0;
      if (isBillable) {
        billableSeconds += seconds;
      } else {
        nonBillableSeconds += seconds;
      }
    }

    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tasks WHERE work_date = ?',
      [workDate],
    );
    final totalTasks = countResult.isNotEmpty ? (countResult.first['count'] as int? ?? 0) : 0;

    return DailySummaryModel(
      workDate: workDate,
      totalSeconds: billableSeconds + nonBillableSeconds,
      billableSeconds: billableSeconds,
      nonBillableSeconds: nonBillableSeconds,
      totalTasks: totalTasks,
    );
  }

  // ---------------------------------------------------------------------------
  // CSV EXPORT QUERY
  // ---------------------------------------------------------------------------

  Future<List<CsvExportRow>> getCsvExportData({
    String? singleDate,
    String? startDate,
    String? endDate,
  }) async {
    final db = await instance.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (singleDate != null) {
      whereClause = 'WHERE te.work_date = ?';
      whereArgs = [singleDate];
    } else if (startDate != null && endDate != null) {
      whereClause = 'WHERE te.work_date >= ? AND te.work_date <= ?';
      whereArgs = [startDate, endDate];
    }

    final query = '''
      SELECT 
        te.work_date AS date,
        COALESCE(e.employee_email, 'employee@company.com') AS employee_email,
        p.project_name,
        t.task_description,
        t.billable,
        SUM(te.duration_seconds) AS total_duration_seconds
      FROM time_entries te
      JOIN tasks t ON te.task_id = t.id
      JOIN projects p ON t.project_id = p.id
      LEFT JOIN employees e ON te.employee_id = e.id
      $whereClause
      GROUP BY te.work_date, t.id
      ORDER BY te.work_date ASC, p.project_name ASC, t.task_description ASC
    ''';

    final results = await db.rawQuery(query, whereArgs);

    return results.map((row) {
      final date = row['date'] as String? ?? '';
      final email = row['employee_email'] as String? ?? 'employee@company.com';
      final projectName = row['project_name'] as String? ?? '';
      final description = row['task_description'] as String? ?? '';
      final isBillable = (row['billable'] as int? ?? 1) == 1;
      final totalSeconds = row['total_duration_seconds'] as int? ?? 0;

      // Convert seconds to minutes. If time was tracked (>0s) but <30s, give at least 1 min or standard round
      int minutes = (totalSeconds / 60.0).round();
      if (minutes == 0 && totalSeconds > 0) {
        minutes = 1; // Preserve any actual tracking session
      }

      return CsvExportRow(
        date: date,
        employeeEmail: email,
        projectName: projectName,
        taskDescription: description,
        minutes: minutes,
        billable: isBillable,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // DATABASE STATS FOR SETTINGS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getStorageInfo() async {
    final dbPath = await getDatabasePath();
    final file = File(dbPath);
    final exists = await file.exists();
    final sizeBytes = exists ? await file.length() : 0;

    final db = await instance.database;
    final taskCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM tasks');
    final taskCount = taskCountResult.isNotEmpty ? (taskCountResult.first['count'] as int? ?? 0) : 0;

    final entryCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM time_entries');
    final entryCount = entryCountResult.isNotEmpty ? (entryCountResult.first['count'] as int? ?? 0) : 0;

    final projectCountResult = await db.rawQuery('SELECT COUNT(*) as count FROM projects');
    final projectCount = projectCountResult.isNotEmpty ? (projectCountResult.first['count'] as int? ?? 0) : 0;

    return {
      'path': dbPath,
      'sizeBytes': sizeBytes,
      'taskCount': taskCount,
      'entryCount': entryCount,
      'projectCount': projectCount,
    };
  }
}
