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
import 'package:app/screens/schedules/schedule_form_dialog.dart';
import 'package:app/screens/schedules/schedule_screen.dart';
import 'package:app/screens/subjects/subject_detail_screen.dart';
import 'package:app/screens/subjects/subjects_screen.dart';
import 'package:app/screens/tasks/task_form_dialog.dart';
import 'package:app/screens/tasks/tasks_screen.dart';
import 'package:app/services/sync_service.dart';

class NoopSyncService extends SyncService {
  @override
  Future<SyncResult> synchronize() async {
    return SyncResult(success: true);
  }
}

class TestSubjectProvider extends SubjectProvider {
  final List<Subject> testSubjects;
  TestSubjectProvider(this.testSubjects);

  @override
  List<Subject> get subjects => testSubjects;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadSubjects({bool triggerSync = true}) async {}
}

class TestScheduleProvider extends ScheduleProvider {
  final List<Schedule> testSchedules;
  TestScheduleProvider(this.testSchedules);

  @override
  List<Schedule> get schedules => testSchedules;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadSchedules() async {}

  @override
  List<Schedule> getSchedulesForDay(int dayOfWeek) {
    return testSchedules.where((s) => s.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }
}

class TestTaskProvider extends TaskProvider {
  final List<TaskItem> testTasks;
  TestTaskProvider(this.testTasks);

  @override
  List<TaskItem> get tasks => testTasks;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadTasks() async {}
}

class TestAbsenceProvider extends AbsenceProvider {
  final List<Absence> testAbsences;
  TestAbsenceProvider(this.testAbsences);

  @override
  List<Absence> get absences => testAbsences;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadAbsences(String subjectId) async {}
}

class TestGradeProvider extends GradeProvider {
  final List<Grade> testGrades;
  TestGradeProvider(this.testGrades);

  @override
  List<Grade> get grades => testGrades;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadGrades(String subjectId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleSubject = Subject(
    id: 'sub-smoke-1',
    name: 'Cálculo Avanzado',
    teacher: 'Dr. Gauss',
    color: '#3B82F6',
    maxAbsences: 5,
    passingGrade: 8.0,
    gradeScale: 10.0,
  );

  final sampleSchedule = Schedule(
    id: 'sch-smoke-1',
    subjectId: 'sub-smoke-1',
    dayOfWeek: 1, // Lunes
    startTime: '08:00',
    endTime: '10:00',
    room: 'Aula 101',
  );

  final sampleTask = TaskItem(
    id: 'task-smoke-1',
    subjectId: 'sub-smoke-1',
    title: 'Tarea 1 Integrales',
    dueAt: DateTime.now().add(const Duration(days: 1)),
    kind: 'task',
    reminders: [1440, 120],
  );

  final sampleAbsence = Absence(
    id: 'abs-smoke-1',
    subjectId: 'sub-smoke-1',
    date: '2026-11-19',
    justified: false,
    note: 'Cita médica',
  );

  final sampleGrade = Grade(
    id: 'grd-smoke-1',
    subjectId: 'sub-smoke-1',
    name: 'Parcial 1',
    weight: 30.0,
    score: 8.5,
  );

  final sampleGradePending = Grade(
    id: 'grd-smoke-2',
    subjectId: 'sub-smoke-1',
    name: 'Examen Final',
    weight: 70.0,
    score: null,
  );

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

  Widget buildTestApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<SubjectProvider>(create: (_) => TestSubjectProvider([sampleSubject])),
        ChangeNotifierProvider<ScheduleProvider>(create: (_) => TestScheduleProvider([sampleSchedule])),
        ChangeNotifierProvider<TaskProvider>(create: (_) => TestTaskProvider([sampleTask])),
        ChangeNotifierProvider<AbsenceProvider>(create: (_) => TestAbsenceProvider([sampleAbsence])),
        ChangeNotifierProvider<GradeProvider>(create: (_) => TestGradeProvider([sampleGrade, sampleGradePending])),
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

  group('Widget Smoke Tests - Pantallas principales y diálogos sin excepciones', () {
    testWidgets('1. Pantalla de Inicio (HomeScreen) construye sin errores', (tester) async {
      await tester.pumpWidget(buildTestApp(const HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('MiSemestre UTM'), findsOneWidget);
      expect(find.text('Pendientes de hoy'), findsOneWidget);
    });

    testWidgets('2. Pantalla de Horario (ScheduleScreen) construye sin errores', (tester) async {
      await tester.pumpWidget(buildTestApp(const ScheduleScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ScheduleScreen), findsOneWidget);
      expect(find.text('Horario Semanal'), findsOneWidget);
      expect(find.text('Lun'), findsOneWidget);
    });

    testWidgets('3. Pantalla de Tareas (TasksScreen) construye sin errores (verifica formato es)', (tester) async {
      await tester.pumpWidget(buildTestApp(const TasksScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TasksScreen), findsOneWidget);
      expect(find.text('Tareas y Exámenes'), findsOneWidget);
      expect(find.text('Tarea 1 Integrales'), findsOneWidget);
    });

    testWidgets('4. Pantalla de Materias (SubjectsScreen) construye sin errores', (tester) async {
      await tester.pumpWidget(buildTestApp(const SubjectsScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(SubjectsScreen), findsOneWidget);
      expect(find.text('Materias'), findsOneWidget);
      expect(find.text('Cálculo Avanzado'), findsOneWidget);
    });

    testWidgets('5. Detalle de Materia (SubjectDetailScreen) con sus 3 pestañas', (tester) async {
      await tester.pumpWidget(buildTestApp(SubjectDetailScreen(subject: sampleSubject)));
      await tester.pumpAndSettle();

      expect(find.byType(SubjectDetailScreen), findsOneWidget);
      expect(find.text('Cálculo Avanzado'), findsOneWidget);

      // Pestaña 1: Simulador (activa por defecto)
      expect(find.text('Simulador'), findsOneWidget);
      expect(find.text('¿Y si saco...?'), findsOneWidget);
      expect(find.text('Puntos asegurados'), findsOneWidget);

      // Pestaña 2: Faltas
      await tester.tap(find.text('Faltas'));
      await tester.pumpAndSettle();
      expect(find.text('Falta de hoy (1 toque)'), findsOneWidget);
      expect(find.text('Otra fecha'), findsOneWidget);
      expect(find.text('2026-11-19'), findsOneWidget);

      // Pestaña 3: Evaluaciones
      await tester.tap(find.text('Evaluaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Evaluaciones'), findsWidgets);
      expect(find.text('Parcial 1'), findsOneWidget);
    });

    testWidgets('6. Formulario de Tarea (TaskFormDialog) construye y formatea fecha en español', (tester) async {
      await tester.pumpWidget(buildTestApp(const TaskFormDialog()));
      await tester.pumpAndSettle();

      expect(find.byType(TaskFormDialog), findsOneWidget);
      expect(find.text('Nueva Actividad'), findsOneWidget);
      expect(find.text('Fecha y hora de entrega *'), findsOneWidget);
    });

    testWidgets('7. Formulario de Clase (ScheduleFormDialog) construye sin errores', (tester) async {
      await tester.pumpWidget(buildTestApp(const ScheduleFormDialog()));
      await tester.pumpAndSettle();

      expect(find.byType(ScheduleFormDialog), findsOneWidget);
      expect(find.text('Agregar Clase'), findsOneWidget);
      expect(find.text('Día *'), findsOneWidget);
    });
  });
}
