import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/project_model.dart';
import '../services/time_tracking_service.dart';
import '../theme/app_colors.dart';
import 'add_project_dialog.dart';

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
  final _taskTitleController = TextEditingController();
  final _timeService = TimeTrackingService();
  final _dbHelper = DatabaseHelper.instance;

  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  bool _isBillable = true;
  bool _isLoadingProjects = true;
  bool _isSubmitting = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects({int? selectProjectId}) async {
    if (!mounted) return;
    setState(() => _isLoadingProjects = true);
    try {
      final projects = await _dbHelper.getProjects(includeArchived: false);
      if (!mounted) return;
      setState(() {
        _projects = projects;
        if (selectProjectId != null) {
          _selectedProject = projects.where((p) => p.id == selectProjectId).firstOrNull ??
              (projects.isNotEmpty ? projects.first : null);
        } else if (_selectedProject == null && projects.isNotEmpty) {
          _selectedProject = projects.first;
        } else if (_selectedProject != null && !projects.any((p) => p.id == _selectedProject!.id)) {
          _selectedProject = projects.isNotEmpty ? projects.first : null;
        }
      });
    } catch (e) {
      debugPrint('Error loading projects: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingProjects = false);
      }
    }
  }

  Future<void> _handleAddNewProject() async {
    final newProject = await AddProjectDialog.show(context);
    if (mounted && newProject != null) {
      await _loadProjects(selectProjectId: newProject.id);
    }
  }

  Future<void> _submitTask() async {
    final taskText = _taskTitleController.text.trim();

    if (_selectedProject == null) {
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
      await _timeService.addTask(
        projectId: _selectedProject!.id!,
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
          Row(
            children: [
              const Icon(Icons.work_outline_rounded, size: 15, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              const Text(
                'Select Project',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _handleAddNewProject,
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'New Project',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Project Dropdown Row
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
                  child: _isLoadingProjects
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedProject?.id,
                            isExpanded: true,
                            hint: const Text('Choose a project...', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                            items: [
                              ..._projects.map(
                                (proj) => DropdownMenuItem<int>(
                                  value: proj.id,
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
                                ),
                              ),
                            ],
                            onChanged: (id) {
                              if (id != null) {
                                setState(() {
                                  _selectedProject = _projects.firstWhere((p) => p.id == id);
                                  _validationError = null;
                                });
                              }
                            },
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              // Quick Add Project Button
              IconButton(
                tooltip: 'Add New Project',
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryGreen, size: 20),
                onPressed: _handleAddNewProject,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryGreenLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(40, 40),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Task Title & Controls
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              const Text(
                'Task Title',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Responsive Task Input & Add Button
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 560;

              final taskInput = TextField(
                controller: _taskTitleController,
                style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                decoration: const InputDecoration(
                  hintText: 'What are you working on? (e.g. Fix authentication issue)',
                  prefixIcon: Icon(Icons.list_alt_rounded, size: 18, color: AppColors.textSecondary),
                ),
                onSubmitted: (_) => _submitTask(),
                onChanged: (_) {
                  if (_validationError != null) {
                    setState(() => _validationError = null);
                  }
                },
              );

              final billableToggle = Container(
                height: 42,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLightGreen,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBillingOption(
                      title: 'Billable',
                      isSelected: _isBillable,
                      onTap: () => setState(() => _isBillable = true),
                    ),
                    _buildBillingOption(
                      title: 'Non-billable',
                      isSelected: !_isBillable,
                      onTap: () => setState(() => _isBillable = false),
                    ),
                  ],
                ),
              );

              final addButton = SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_task_rounded, size: 17),
                  label: const Text(
                    'Add Task',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    taskInput,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: billableToggle),
                        const SizedBox(width: 8),
                        addButton,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: taskInput),
                  const SizedBox(width: 10),
                  billableToggle,
                  const SizedBox(width: 10),
                  addButton,
                ],
              );
            },
          ),

          if (_validationError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.deleteRed),
                const SizedBox(width: 6),
                Text(
                  _validationError!,
                  style: const TextStyle(fontSize: 12, color: AppColors.deleteRed),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillingOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected
                    ? (title == 'Billable' ? AppColors.billableGreen : AppColors.nonBillableGray)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
