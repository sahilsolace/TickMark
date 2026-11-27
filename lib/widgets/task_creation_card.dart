import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tickmark/controllers/time_tracking_controller.dart';
import 'package:tickmark/controllers/timesheet_controller.dart';
import 'package:tickmark/models/project_model.dart';
import 'package:tickmark/theme/app_colors.dart';

class TaskCreationCard extends StatefulWidget {
  final VoidCallback onTaskAdded;

  const TaskCreationCard({
    super.key,
    required this.onTaskAdded,
  });

  @override
  State<TaskCreationCard> createState() => _TaskCreationCardState();
}

class _TaskCreationCardState extends State<TaskCreationCard> {
  final TextEditingController _taskTitleController = TextEditingController();

  final TimeTrackingController _timeController = Get.isRegistered<TimeTrackingController>()
      ? Get.find<TimeTrackingController>()
      : Get.put<TimeTrackingController>(TimeTrackingController());

  final TimesheetController _timesheetController = Get.isRegistered<TimesheetController>()
      ? Get.find<TimesheetController>()
      : Get.put<TimesheetController>(TimesheetController());

  ProjectModel? _selectedProject;
  bool _isBillable = true;
  bool _isSubmitting = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _timesheetController.fetchProjects();
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    super.dispose();
  }

  Future<void> _submitTask() async {
    final String taskText = _taskTitleController.text.trim();

    final List<ProjectModel> projects = _timesheetController.projects.toList();
    ProjectModel? project = _selectedProject;
    if (project == null && projects.isNotEmpty) {
      project = projects.first;
    }

    if (project == null) {
      setState(() => _validationError = 'Please select a project');
      return;
    }

    if (taskText.isEmpty) {
      setState(() => _validationError = 'Please enter a task title / description');
      return;
    }

    setState(() {
      _validationError = null;
      _isSubmitting = true;
    });

    try {
      final int pid = project.id ?? project.projectId;
      await _timeController.addTask(
        projectId: pid,
        taskDescription: taskText,
        billable: _isBillable,
      );

      if (!mounted) return;
      _taskTitleController.clear();
      widget.onTaskAdded();
    } catch (e) {
      if (mounted) {
        setState(() => _validationError = 'Failed to create task: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title: Select Project
          const Row(
            children: [
              Icon(Icons.work_outline_rounded, size: 15, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              Text(
                'Select Project',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Project Dropdown Row (Reactive with Obx)
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Obx(() {
                    if (_timesheetController.isLoadingProjects.value) {
                      return const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                        ),
                      );
                    }

                    final List<ProjectModel> projects = _timesheetController.projects.toList();
                    final int? currentId = _selectedProject?.id ??
                        (_selectedProject?.projectId != null && _selectedProject!.projectId > 0
                            ? _selectedProject!.projectId
                            : (projects.isNotEmpty ? (projects.first.id ?? projects.first.projectId) : null));

                    return DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: projects.any((p) => (p.id ?? p.projectId) == currentId) ? currentId : null,
                        isExpanded: true,
                        hint: const Text('Choose a project...', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                        items: projects.map((ProjectModel proj) {
                          final int pVal = proj.id ?? proj.projectId;
                          return DropdownMenuItem<int>(
                            value: pVal,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  proj.projectName,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (int? id) {
                          if (id != null) {
                            setState(() {
                              _selectedProject = projects.firstWhere((p) => (p.id ?? p.projectId) == id);
                              _validationError = null;
                            });
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 8),
              // Refresh Projects from API
              IconButton(
                tooltip: 'Refresh Projects from API',
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryGreen, size: 20),
                onPressed: () => _timesheetController.fetchProjects(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryGreenLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(40, 40),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Section Title: Task Description
          const Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 16, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              Text(
                'Task Description',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Task Input Field
          TextField(
            controller: _taskTitleController,
            maxLines: 2,
            minLines: 1,
            style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'What are you working on? (e.g. Fix authentication issue)',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              errorText: _validationError,
            ),
            onChanged: (text) {
              if (_validationError != null && text.trim().isNotEmpty) {
                setState(() => _validationError = null);
              }
            },
          ),

          const SizedBox(height: 12),

          // Bottom Controls: Billable / Non-Billable & Add Task Button
          Row(
            children: [
              // Billable / Non-Billable Segment
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBillableTab(
                      label: 'Billable',
                      isSelected: _isBillable,
                      onTap: () => setState(() => _isBillable = true),
                    ),
                    _buildBillableTab(
                      label: 'Non-Billable',
                      isSelected: !_isBillable,
                      onTap: () => setState(() => _isBillable = false),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_task_rounded, size: 16),
                label: Text(
                  _isSubmitting ? 'Adding...' : 'Add Task',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillableTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
