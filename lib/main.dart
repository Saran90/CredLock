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

  // Catch any unhandled exceptions
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔴 Flutter Error: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };

  try {
    debugPrint('🟡 Initializing AuthService...');
    await AuthService.instance.init();
    debugPrint('✅ AuthService initialized');

    debugPrint('🟡 Initializing Workmanager...');
    await Workmanager().initialize(callbackDispatcher);
    debugPrint('✅ Workmanager initialized');

    debugPrint('🟡 Initializing NotificationService...');
    await NotificationService.instance.init();
    debugPrint('✅ NotificationService initialized');

    debugPrint('🟡 Initializing ReminderService...');
    await ReminderService.instance.init();
    debugPrint('✅ ReminderService initialized');
  } catch (e, st) {
    debugPrint('🔴 Initialization error: $e');
    debugPrintStack(stackTrace: st);
  }

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
