class TimeEntryModel {
  final int? id;
  final int taskId;
  final int employeeId;
  final String startTimestamp;
  final String? endTimestamp;
  final int durationSeconds;
  final String workDate; // YYYY-MM-DD
  final bool isActive;
  final String createdAt;

  TimeEntryModel({
    this.id,
    required this.taskId,
    required this.employeeId,
    required this.startTimestamp,
    this.endTimestamp,
    this.durationSeconds = 0,
    required this.workDate,
    this.isActive = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'task_id': taskId,
      'employee_id': employeeId,
      'start_timestamp': startTimestamp,
      'end_timestamp': endTimestamp,
      'duration_seconds': durationSeconds,
      'work_date': workDate,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory TimeEntryModel.fromMap(Map<String, dynamic> map) {
    return TimeEntryModel(
      id: map['id'] as int?,
      taskId: map['task_id'] as int? ?? 0,
      employeeId: map['employee_id'] as int? ?? 0,
      startTimestamp: map['start_timestamp'] as String? ?? '',
      endTimestamp: map['end_timestamp'] as String?,
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      workDate: map['work_date'] as String? ?? '',
      isActive: (map['is_active'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  TimeEntryModel copyWith({
    int? id,
    int? taskId,
    int? employeeId,
    String? startTimestamp,
    String? endTimestamp,
    int? durationSeconds,
    String? workDate,
    bool? isActive,
    String? createdAt,
  }) {
    return TimeEntryModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      employeeId: employeeId ?? this.employeeId,
      startTimestamp: startTimestamp ?? this.startTimestamp,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      workDate: workDate ?? this.workDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
