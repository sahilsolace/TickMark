import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import 'controllers/auth_controller.dart';
import 'controllers/time_tracking_controller.dart';
import 'controllers/timesheet_controller.dart';
import 'database/database_helper.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for Windows Desktop
  DatabaseHelper.initializeFfi();

  // Initialize Window Manager
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(840, 680),
    minimumSize: Size(320, 130),
    center: true,
    title: 'TickMark',
    backgroundColor: Color(0xFFE8F7E9),
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(
    windowOptions,
    () async {
      await windowManager.setAsFrameless();
      await windowManager.setPreventClose(true);
      await windowManager.setResizable(true);
      await windowManager.show();
      await windowManager.focus();
    },
  );

  // Initialize GetX global controllers
  Get.put<AuthController>(AuthController(), permanent: true);
  Get.put<TimeTrackingController>(TimeTrackingController(), permanent: true);
  Get.put<TimesheetController>(TimesheetController(), permanent: true);

  runApp(const TickMarkApp());
}

class TickMarkApp extends StatelessWidget {
  const TickMarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'TickMark',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
