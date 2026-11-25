class TaskModel {
  final int? id;
  final int projectId;
  final String projectName;
  final String taskDescription;
  final bool billable;
  final String workDate; // YYYY-MM-DD
  final String createdAt;
  final String updatedAt;

  // Runtime timer stats
  final int totalDurationSeconds;
  final bool isRunning;
  final DateTime? activeStartTimestamp;

  TaskModel({
    this.id,
    required this.projectId,
    required this.projectName,
    required this.taskDescription,
    this.billable = true,
    required this.workDate,
    required this.createdAt,
    required this.updatedAt,
    this.totalDurationSeconds = 0,
    this.isRunning = false,
    this.activeStartTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'project_id': projectId,
      'task_description': taskDescription,
      'billable': billable ? 1 : 0,
      'work_date': workDate,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, {String projectName = ''}) {
    return TaskModel(
      id: map['id'] as int?,
      projectId: map['project_id'] as int? ?? 0,
      projectName: map['project_name'] as String? ?? projectName,
      taskDescription: map['task_description'] as String? ?? '',
      billable: (map['billable'] as int? ?? 1) == 1,
      workDate: map['work_date'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      totalDurationSeconds: map['total_duration_seconds'] as int? ?? 0,
    );
  }

  TaskModel copyWith({
    int? id,
    int? projectId,
    String? projectName,
    String? taskDescription,
    bool? billable,
    String? workDate,
    String? createdAt,
    String? updatedAt,
    int? totalDurationSeconds,
    bool? isRunning,
    DateTime? activeStartTimestamp,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      taskDescription: taskDescription ?? this.taskDescription,
      billable: billable ?? this.billable,
      workDate: workDate ?? this.workDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      isRunning: isRunning ?? this.isRunning,
      activeStartTimestamp: activeStartTimestamp ?? this.activeStartTimestamp,
    );
  }

  String get formattedDuration {
    final hours = (totalDurationSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalDurationSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalDurationSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
