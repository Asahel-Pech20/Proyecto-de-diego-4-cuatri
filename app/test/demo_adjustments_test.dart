import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/config/constants.dart';
import 'package:app/models/absence.dart';
import 'package:app/models/grade.dart';
import 'package:app/models/schedule.dart';
import 'package:app/models/subject.dart';
import 'package:app/models/task_item.dart';
import 'package:app/providers/absence_provider.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/grade_provider.dart';
import 'package:app/providers/schedule_provider.dart';
import 'package:app/providers/subject_provider.dart';
import 'package:app/providers/task_provider.dart';
import 'package:app/screens/home/home_screen.dart';
import 'package:app/screens/subjects/subject_detail_screen.dart';
import 'package:app/screens/tasks/tasks_screen.dart';
import 'package:app/services/sync_service.dart';

class NoopSyncService extends SyncService {
  @override
  Future<SyncResult> synchronize() async {
    return SyncResult(success: true);
  }
}

class MockSubjectProvider extends SubjectProvider {
  final List<Subject> list;
  MockSubjectProvider(this.list);
  @override
  List<Subject> get subjects => list;
  @override
  bool get isLoading => false;
  @override
  Future<void> loadSubjects({bool triggerSync = true}) async {}
}

class MockScheduleProvider extends ScheduleProvider {
  final List<Schedule> list;
  MockScheduleProvider(this.list);
  @override
  List<Schedule> get schedules => list;
  @override
  bool get isLoading => false;
}

class MockTaskProvider extends TaskProvider {
  final List<TaskItem> list;
  MockTaskProvider(this.list);
  @override
  List<TaskItem> get tasks => list;
  @override
  bool get isLoading => false;
  @override
  GroupedTasks get groupedTasks => TaskProvider.groupTasks(list);
  @override
  Future<void> loadTasks() async {}
}

class MockAbsenceProvider extends AbsenceProvider {
  final List<Absence> list;
  MockAbsenceProvider(this.list);
  @override
  List<Absence> get absences => list;
  @override
  bool get isLoading => false;
  @override
  Future<void> loadAbsences(String subjectId) async {}
}

class MockGradeProvider extends GradeProvider {
  final List<Grade> list;
  MockGradeProvider(this.list);
  @override
  List<Grade> get grades => list;
  @override
  bool get isLoading => false;
  @override
  Future<void> loadGrades(String subjectId) async {}
}

Widget createTestApp({
  required Widget child,
  required List<Subject> subjects,
  required List<TaskItem> tasks,
  required List<Absence> absences,
  List<Schedule> schedules = const [],
  List<Grade> grades = const [],
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ChangeNotifierProvider<SubjectProvider>(create: (_) => MockSubjectProvider(subjects)),
      ChangeNotifierProvider<ScheduleProvider>(create: (_) => MockScheduleProvider(schedules)),
      ChangeNotifierProvider<TaskProvider>(create: (_) => MockTaskProvider(tasks)),
      ChangeNotifierProvider<AbsenceProvider>(create: (_) => MockAbsenceProvider(absences)),
      ChangeNotifierProvider<GradeProvider>(create: (_) => MockGradeProvider(grades)),
    ],
    child: MaterialApp(
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
        ),
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es');
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'read') return 'mock_token';
        return null;
      },
    );
  });

  setUp(() {
    SyncService.instance = NoopSyncService();
  });

  group('Ajustes para Demo en Emulador', () {
    final sampleSubject = Subject(
      id: 'sub-demo-1',
      name: 'Redes',
      color: '#7A1C2E',
    );

    testWidgets('1a. Tarea pendiente de sync muestra etiqueta "Pendiente sync" en TasksScreen', (tester) async {
      final pendingTask = TaskItem(
        id: 'task-demo-pending',
        subjectId: 'sub-demo-1',
        title: 'Práctica de Subnetting',
        dueAt: DateTime.now().add(const Duration(hours: 2)),
        syncStatus: 'pending_create',
      );

      await tester.pumpWidget(createTestApp(
        child: const TasksScreen(),
        subjects: [sampleSubject],
        tasks: [pendingTask],
        absences: const [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Práctica de Subnetting'), findsOneWidget);
      expect(find.text('Pendiente sync'), findsOneWidget);
    });

    testWidgets('1b. Tarea pendiente de sync muestra etiqueta "Pendiente sync" en HomeScreen', (tester) async {
      final pendingTask = TaskItem(
        id: 'task-demo-pending-home',
        subjectId: 'sub-demo-1',
        title: 'Práctica de Routers',
        dueAt: DateTime.now().add(const Duration(hours: 2)),
        syncStatus: 'pending_create',
      );

      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        subjects: [sampleSubject],
        tasks: [pendingTask],
        absences: const [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Práctica de Routers'), findsOneWidget);
      expect(find.text('Pendiente sync'), findsOneWidget);
    });

    testWidgets('1c. Tarea sincronizada (synced) no muestra etiqueta "Pendiente sync" en TasksScreen ni en HomeScreen', (tester) async {
      final syncedTask = TaskItem(
        id: 'task-demo-synced',
        subjectId: 'sub-demo-1',
        title: 'Práctica Final',
        dueAt: DateTime.now().add(const Duration(hours: 2)),
        syncStatus: 'synced',
      );

      await tester.pumpWidget(createTestApp(
        child: const TasksScreen(),
        subjects: [sampleSubject],
        tasks: [syncedTask],
        absences: const [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Práctica Final'), findsOneWidget);
      expect(find.text('Pendiente sync'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        subjects: [sampleSubject],
        tasks: [syncedTask],
        absences: const [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Práctica Final'), findsOneWidget);
      expect(find.text('Pendiente sync'), findsNothing);
    });

    testWidgets('2. Cuando las faltas superan el límite, "Restantes" muestra 0 en vez de número negativo', (tester) async {
      final subject = Subject(
        id: 'sub-demo-2',
        name: 'Sistemas Distribuidos',
        color: '#1E40AF',
        maxAbsences: 3,
        passingGrade: 8.0,
        gradeScale: 10.0,
      );

      // 4 faltas injustificadas en una materia con límite de 3 (supera por 1 falta: 3 - 4 = -1)
      final fourAbsences = [
        Absence(id: 'a1', subjectId: 'sub-demo-2', date: '2026-11-01', justified: false),
        Absence(id: 'a2', subjectId: 'sub-demo-2', date: '2026-11-05', justified: false),
        Absence(id: 'a3', subjectId: 'sub-demo-2', date: '2026-11-10', justified: false),
        Absence(id: 'a4', subjectId: 'sub-demo-2', date: '2026-11-15', justified: false),
      ];

      await tester.pumpWidget(createTestApp(
        child: SubjectDetailScreen(subject: subject),
        subjects: [subject],
        tasks: const [],
        absences: fourAbsences,
      ));
      await tester.pumpAndSettle();

      // Debe mostrar el aviso de límite superado en la pestaña Simulador (pestaña principal del detalle)
      expect(find.text('Límite de faltas superado. Estás en situación no aprobatoria por inasistencias.'), findsOneWidget);

      // La estadística de "Restantes" debe mostrar 0 y NO -1
      expect(find.text('Restantes'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(find.text('-1'), findsNothing);
    });
  });
}
