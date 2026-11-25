import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/project_model.dart';
import '../services/time_tracking_service.dart';
import '../theme/app_colors.dart';
import 'add_project_dialog.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dbHelper = DatabaseHelper.instance;
  final _timeService = TimeTrackingService();

  // Employee controllers
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _employeeFormKey = GlobalKey<FormState>();
  bool _isSavingEmployee = false;
  String? _employeeSuccessMessage;

  // Projects list
  List<ProjectModel> _projects = [];
  bool _isLoadingProjects = true;

  // Storage info
  Map<String, dynamic> _storageInfo = {};
  bool _isLoadingStorage = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadEmployee(),
      _loadProjects(),
      _loadStorageInfo(),
    ]);
  }

  Future<void> _loadEmployee() async {
    final emp = await _dbHelper.getEmployee();
    _emailController.text = emp.employeeEmail;
    _nameController.text = emp.employeeName ?? '';
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoadingProjects = true);
    final projs = await _dbHelper.getProjects(includeArchived: true);
    setState(() {
      _projects = projs;
      _isLoadingProjects = false;
    });
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _isLoadingStorage = true);
    final info = await _dbHelper.getStorageInfo();
    setState(() {
      _storageInfo = info;
      _isLoadingStorage = false;
    });
  }

  Future<void> _saveEmployee() async {
    if (!_employeeFormKey.currentState!.validate()) return;

    setState(() {
      _isSavingEmployee = true;
      _employeeSuccessMessage = null;
    });

    final currentEmp = await _dbHelper.getEmployee();
    final updated = currentEmp.copyWith(
      employeeEmail: _emailController.text.trim(),
      employeeName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
    );

    await _dbHelper.updateEmployee(updated);
    await _timeService.refreshEmployee();

    setState(() {
      _isSavingEmployee = false;
      _employeeSuccessMessage = 'Employee details saved successfully!';
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _employeeSuccessMessage = null);
      }
    });
  }

  Future<void> _renameProject(ProjectModel project) async {
    final controller = TextEditingController(text: project.projectName);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: const Text('Rename Project', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Project Name'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Project name cannot be empty' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != project.projectName) {
      await _dbHelper.updateProject(project.id!, newName);
      await _loadProjects();
    }
  }

  Future<void> _toggleArchive(ProjectModel project) async {
    await _dbHelper.setProjectArchived(project.id!, !project.isArchived);
    await _loadProjects();
  }

  void _openDatabaseFolder() {
    final path = _storageInfo['path'] as String?;
    if (path != null && Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
      actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings_outlined, color: AppColors.primaryGreen, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings & Preferences',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              SizedBox(height: 2),
              Text(
                'Manage employee profile, projects, and local database',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 440,
        child: Column(
          children: [
            const Divider(),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryGreen,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryGreen,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Employee Profile'),
                Tab(icon: Icon(Icons.folder_copy_outlined, size: 18), text: 'Projects'),
                Tab(icon: Icon(Icons.storage_outlined, size: 18), text: 'Storage & System'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEmployeeTab(),
                  _buildProjectsTab(),
                  _buildStorageTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildEmployeeTab() {
    return Form(
      key: _employeeFormKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee Identification',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'This email address will be stored locally and automatically included in all exported CSV timesheets.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Email input
            const Text('Employee Email *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                hintText: 'employee@company.com',
                prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppColors.textSecondary),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Employee email is required';
                }
                if (!val.contains('@') || !val.contains('.')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Name input
            const Text('Employee Display Name (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. John Doe',
                prefixIcon: Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isSavingEmployee ? null : _saveEmployee,
                  icon: _isSavingEmployee
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Save Profile'),
                ),
                if (_employeeSuccessMessage != null) ...[
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: AppColors.primaryGreen),
                      const SizedBox(width: 6),
                      Text(
                        _employeeSuccessMessage!,
                        style: const TextStyle(fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Manage Projects',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            FilledButton.icon(
              onPressed: () async {
                final newProj = await AddProjectDialog.show(context);
                if (newProj != null) {
                  await _loadProjects();
                }
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Project', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'You can add, rename, or archive projects. Archiving hides a project from new tasks while preserving all historical tracking records.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _isLoadingProjects
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
              : _projects.isEmpty
                  ? const Center(child: Text('No projects available.'))
                  : ListView.separated(
                      itemCount: _projects.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final proj = _projects[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: Icon(
                            proj.isArchived ? Icons.archive_outlined : Icons.folder_outlined,
                            color: proj.isArchived ? AppColors.textMuted : AppColors.primaryGreen,
                            size: 20,
                          ),
                          title: Row(
                            children: [
                              Text(
                                proj.projectName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: proj.isArchived ? AppColors.textMuted : AppColors.textDark,
                                  decoration: proj.isArchived ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (proj.isArchived)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Archived', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Rename',
                                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                                onPressed: () => _renameProject(proj),
                              ),
                              IconButton(
                                tooltip: proj.isArchived ? 'Unarchive' : 'Archive',
                                icon: Icon(
                                  proj.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                                  size: 16,
                                  color: proj.isArchived ? AppColors.primaryGreen : AppColors.textSecondary,
                                ),
                                onPressed: () => _toggleArchive(proj),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStorageTab() {
    if (_isLoadingStorage) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen));
    }

    final path = _storageInfo['path'] as String? ?? '';
    final sizeBytes = _storageInfo['sizeBytes'] as int? ?? 0;
    final sizeKb = (sizeBytes / 1024).toStringAsFixed(1);
    final taskCount = _storageInfo['taskCount'] as int? ?? 0;
    final entryCount = _storageInfo['entryCount'] as int? ?? 0;
    final projectCount = _storageInfo['projectCount'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Local SQLite Database Information',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'All projects, tasks, and time entries are stored locally on your machine.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // Database file path box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storage_rounded, size: 16, color: AppColors.primaryGreen),
                    const SizedBox(width: 6),
                    const Text('Database Path:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Copy Path',
                      icon: const Icon(Icons.copy, size: 14, color: AppColors.textSecondary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: path));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Database path copied to clipboard')),
                        );
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: 'Open in Explorer',
                      icon: const Icon(Icons.folder_open, size: 14, color: AppColors.textSecondary),
                      onPressed: _openDatabaseFolder,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  path,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Database Size', '$sizeKb KB', Icons.data_usage),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem('Total Tasks', '$taskCount', Icons.task_outlined),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem('Time Sessions', '$entryCount', Icons.history),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatItem('Projects', '$projectCount', Icons.folder_outlined),
              ),
            ],
          ),

          const Spacer(),
          const Divider(),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TickMark Desktop • v1.0.0',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              Text(
                'Theme: Clean Soft Green (#087A3D / #E8F7E9)',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryGreen),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
