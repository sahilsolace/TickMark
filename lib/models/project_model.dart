class ProjectModel {
  final int? id;
  final int projectId;
  final String projectName;
  final String description;
  final String status;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  ProjectModel({
    int? id,
    int? projectId,
    required this.projectName,
    this.description = '',
    this.status = '',
    this.isArchived = false,
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? projectId,
        projectId = projectId ?? id ?? 0,
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final pid = json['project_id'] is int
        ? json['project_id'] as int
        : (json['id'] is int ? json['id'] as int : int.tryParse('${json['project_id'] ?? json['id']}') ?? 0);
    return ProjectModel(
      id: pid,
      projectId: pid,
      projectName: json['project_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? '',
      isArchived: (json['is_archived'] as int? ?? 0) == 1,
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map) => ProjectModel.fromJson(map);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'project_name': projectName,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'project_name': projectName,
      'description': description,
      'status': status,
    };
  }

  ProjectModel copyWith({
    int? id,
    int? projectId,
    String? projectName,
    String? description,
    String? status,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      description: description ?? this.description,
      status: status ?? this.status,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
