import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/auth_controller.dart';
import '../database/database_helper.dart';
import 'package:tickmark/models/project_model.dart';
import '../theme/app_colors.dart';
import '../services/timesheet_services.dart';

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

  // Projects list
  List<ProjectModel> _projects = [];
  bool _isLoadingProjects = true;

  // Storage info
  Map<String, dynamic> _storageInfo = {};
  bool _isLoadingStorage = true;
  String? name;
  String? email;

  Future<void> _loadCred() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      name = prefs.getString('name');
      email = prefs.getString('email');
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadCred(),
      _loadProjects(),
      _loadStorageInfo(),
    ]);
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;
    setState(() => _isLoadingProjects = true);
    try {
      final projs = await TimesheetServices.getProject();
      if (!mounted) return;
      setState(() {
        _projects = projs;
        _isLoadingProjects = false;
      });
    } catch (e) {
      final projs = await _dbHelper.getProjects(includeArchived: false);
      if (!mounted) return;
      setState(() {
        _projects = projs;
        _isLoadingProjects = false;
      });
    }
  }

  Future<void> _loadStorageInfo() async {
    if (!mounted) return;
    setState(() => _isLoadingStorage = true);
    final info = await _dbHelper.getStorageInfo();
    if (!mounted) return;
    setState(() {
      _storageInfo = info;
      _isLoadingStorage = false;
    });
  }

  void _openDatabaseFolder() {
    final path = _storageInfo['path'] as String?;
    if (path != null && Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', path]);
    }
  }

  Future<void> _logout() async {
    final authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : Get.put<AuthController>(AuthController());
    await authController.logout();
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
          Spacer(),
          IconButton(onPressed: _logout, icon: Icon(Icons.logout,color: Colors.red,)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employee Identification',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),


          const SizedBox(height: 16),

          // Email input
          const Text('Email ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 6),
          Text('  $email',style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18
          ),),


          const SizedBox(height: 14),

          // Name input
          const Text(' Name ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 6),
          Text('  $name',style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            color: Colors.black87
          ),),
          const SizedBox(height: 16),

        ],
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Projects (API Synced)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'Synced directly from the company server. Read-only.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            IconButton.filledTonal(
              onPressed: _isLoadingProjects ? null : _loadProjects,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Refresh projects from server',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryGreenLight,
                foregroundColor: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _isLoadingProjects
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
              : _projects.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_off_outlined, size: 36, color: AppColors.textMuted),
                          SizedBox(height: 8),
                          Text(
                            'No projects available from server.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _projects.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final proj = _projects[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreenLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.folder_outlined, color: AppColors.primaryGreen, size: 18),
                          ),
                          title: Text(
                            proj.projectName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textDark,
                            ),
                          ),
                          subtitle: Text(
                            proj.description.isNotEmpty
                                ? proj.description
                                : 'Project ID: ${proj.projectId}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.billableBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              proj.status.isNotEmpty ? proj.status.toUpperCase() : 'ACTIVE',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.billableGreen,
                              ),
                            ),
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
