import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/subject_provider.dart';
import 'providers/task_provider.dart';
import 'providers/absence_provider.dart';
import 'providers/grade_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/database_service.dart';
import 'services/home_widget_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar localización para DateFormat con 'es'
  await initializeDateFormatting('es');

  // Inicializar configuración de la API
  await ApiConfig.instance.init();

  // Inicializar notificaciones locales
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Error inicializando NotificationService: $e');
  }

  // Hook para reprogramar recordatorios y actualizar widget tras cada sincronización exitosa
  SyncService.instance.onSyncCompleted = () async {
    try {
      final tasks = await DatabaseService.instance.getTasks();
      final subjects = await DatabaseService.instance.getSubjects();
      final subjectNames = {for (var s in subjects) s.id: s.name};
      await NotificationService.instance.rescheduleAllReminders(tasks, subjectNames);
      await HomeWidgetService.updateWidget();
    } catch (e) {
      debugPrint('Error tras sync (recordatorios/widget): $e');
    }
  };

  runApp(const MiSemestreApp());
}

class MiSemestreApp extends StatelessWidget {
  const MiSemestreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => SubjectProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => AbsenceProvider()),
        ChangeNotifierProvider(create: (_) => GradeProvider()),
      ],
      child: MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        locale: const Locale('es', 'MX'),
        supportedLocales: const [
          Locale('es', 'MX'),
          Locale('es'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppConstants.primaryColor,
            primary: AppConstants.primaryColor,
            surface: AppConstants.surfaceColor,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 1,
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading && auth.token == null) {
      return Scaffold(
        backgroundColor: AppConstants.surfaceColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: AppConstants.primaryColor),
              const SizedBox(height: 12),
              const Text(
                'Cargando MiSemestre UTM...',
                style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (auth.isAuthenticated) {
      return const MainShell();
    }

    return const LoginScreen();
  }
}
