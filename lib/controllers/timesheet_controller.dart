import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:tickmark/models/project_model.dart';
import 'package:tickmark/services/timesheet_services.dart';

class TimesheetController extends GetxController {
  final RxList<ProjectModel> projects = <ProjectModel>[].obs;
  final RxBool isLoadingProjects = false.obs;
  final RxBool isSyncing = false.obs;
  final Rxn<ProjectModel> selectedProject = Rxn<ProjectModel>();

  @override
  void onInit() {
    super.onInit();
    fetchProjects();
  }

  Future<void> fetchProjects() async {
    isLoadingProjects.value = true;
    try {
      final list = await TimesheetServices.getProject();
      projects.assignAll(list);
      if (projects.isNotEmpty &&
          (selectedProject.value == null ||
              !projects.any((p) => p.id == selectedProject.value?.id))) {
        selectedProject.value = projects.first;
      }
    } catch (e) {
      debugPrint('Error in TimesheetController.fetchProjects: $e');
    } finally {
      isLoadingProjects.value = false;
    }
  }

  Future<bool> syncTimesheet({required String date}) async {
    isSyncing.value = true;
    try {
      return await TimesheetServices.syncTimesheet(date: date);
    } finally {
      isSyncing.value = false;
    }
  }
}
