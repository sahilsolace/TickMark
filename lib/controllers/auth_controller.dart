import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../services/auth_service.dart';

class AuthController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool obscureText = true.obs;
  final RxString userName = ''.obs;
  final RxString userEmail = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadSavedCredentials();
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    obscureText.value = !obscureText.value;
  }

  Future<void> loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userEmail.value = prefs.getString('email') ?? '';
      userName.value = prefs.getString('name') ?? '';
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    }
  }

  Future<void> checkLogin() async {
    try {
      final isLogin = await AuthService.validateSession();
      if (isLogin) {
        await loadSavedCredentials();
        Get.offAll(() => const MainScreen());
      }
    } catch (e) {
      debugPrint('Check login error: $e');
    }
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar(
        'Validation Error',
        'Please enter both email and password.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
      return;
    }

    try {
      isLoading.value = true;
      final success = await AuthService.login(email, password);

      if (success) {
        await loadSavedCredentials();
        Get.offAll(() => const MainScreen());
      } else {
        Get.snackbar(
          'Login Failed',
          'Invalid credentials. Please verify your email and password.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Login failed: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      isLoading.value = true;
      await AuthService.logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('email');
      await prefs.remove('name');
      userName.value = '';
      userEmail.value = '';
      emailController.clear();
      passwordController.clear();
      Get.offAll(() => const LoginScreen());
    } catch (e) {
      debugPrint('Logout error: $e');
      Get.offAll(() => const LoginScreen());
    } finally {
      isLoading.value = false;
    }
  }
}
