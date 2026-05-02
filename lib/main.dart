import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminder_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.init();
  await Workmanager().initialize(callbackDispatcher);
  await NotificationService.instance.init();
  await ReminderService.instance.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const CredLockApp());
}

class CredLockApp extends StatelessWidget {
  const CredLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CredLock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
