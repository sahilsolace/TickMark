class EmployeeModel {
  final int? id;
  final String employeeEmail;
  final String? employeeName;
  final String createdAt;
  final String updatedAt;

  EmployeeModel({
    this.id,
    required this.employeeEmail,
    this.employeeName,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_email': employeeEmail,
      'employee_name': employeeName,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: map['id'] as int?,
      employeeEmail: map['employee_email'] as String? ?? 'employee@company.com',
      employeeName: map['employee_name'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  EmployeeModel copyWith({
    int? id,
    String? employeeEmail,
    String? employeeName,
    String? createdAt,
    String? updatedAt,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      employeeEmail: employeeEmail ?? this.employeeEmail,
      employeeName: employeeName ?? this.employeeName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
