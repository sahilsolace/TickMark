import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import 'package:tickmark/models/project_model.dart';
import '../services/timesheet_services.dart';
import 'auth_controller.dart';

class SettingsController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final RxList<ProjectModel> projects = <ProjectModel>[].obs;
  final RxBool isLoadingProjects = true.obs;
  final RxMap<String, dynamic> storageInfo = <String, dynamic>{}.obs;
  final RxBool isLoadingStorage = true.obs;

  final RxString name = ''.obs;
  final RxString email = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadAllData();
  }

  Future<void> loadAllData() async {
    await Future.wait([
      loadCred(),
      loadProjects(),
      loadStorageInfo(),
    ]);
  }

  Future<void> loadCred() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      name.value = prefs.getString('name') ?? '';
      email.value = prefs.getString('email') ?? '';
    } catch (e) {
      debugPrint('Error loading creds in SettingsController: $e');
    }
  }

  Future<void> loadProjects() async {
    isLoadingProjects.value = true;
    try {
      final list = await TimesheetServices.getProject();
      projects.assignAll(list);
    } catch (e) {
      debugPrint('Error loading projects in SettingsController: $e');
      final localList = await _dbHelper.getProjects(includeArchived: false);
      projects.assignAll(localList);
    } finally {
      isLoadingProjects.value = false;
    }
  }

  Future<void> loadStorageInfo() async {
    isLoadingStorage.value = true;
    try {
      final info = await _dbHelper.getStorageInfo();
      storageInfo.assignAll(info);
    } catch (e) {
      debugPrint('Error loading storage info: $e');
    } finally {
      isLoadingStorage.value = false;
    }
  }

  void openDatabaseFolder() {
    final path = storageInfo['path'] as String?;
    if (path != null && Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', path]);
    }
  }

  Future<void> logout() async {
    if (Get.isRegistered<AuthController>()) {
      await Get.find<AuthController>().logout();
    } else {
      final authCtrl = Get.put(AuthController());
      await authCtrl.logout();
    }
  }
}
