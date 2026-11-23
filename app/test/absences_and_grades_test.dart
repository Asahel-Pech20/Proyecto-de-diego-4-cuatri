import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/models/academic_calculator.dart';
import 'package:app/models/absence.dart';
import 'package:app/models/grade.dart';
import 'package:app/models/schedule.dart';
import 'package:app/models/subject.dart';
import 'package:app/models/task_item.dart';
import 'package:app/providers/absence_provider.dart';
import 'package:app/services/api_service.dart';
import 'package:app/services/database_service.dart';
import 'package:app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAbsenceClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' && request.url.path == '/api/absences') {
      final bodyStr = request is http.Request ? request.body : '';
      Map<String, dynamic> parsed = {};
      try {
        parsed = jsonDecode(bodyStr);
      } catch (_) {}

      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'id': parsed['id'] ?? 'abs-mock',
          'subjectId': parsed['subjectId'] ?? 'sub-dup',
          'date': parsed['date'] ?? '2026-11-19',
          'justified': parsed['justified'] ?? false,
          'createdAt': '2026-11-19T10:00:00Z',
          'updatedAt': '2026-11-19T10:00:00Z',
        }))),
        201,
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    ApiService.instance.client = MockAbsenceClient();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
  });

  group('Pruebas Faltas, Calificaciones y Simulador Local', () {
    // (a) Simulador caso base de backend
    test('(a) simulador: Parcial 1 = 7 (30%), Parcial 2 = 8 (30%), Final pendiente (40%), aprobatoria 8', () {
      final grades = [
        Grade(id: '1', subjectId: 'sub-1', name: 'Parcial 1', weight: 30.0, score: 7.0),
        Grade(id: '2', subjectId: 'sub-1', name: 'Parcial 2', weight: 30.0, score: 8.0),
        Grade(id: '3', subjectId: 'sub-1', name: 'Final', weight: 40.0, score: null),
      ];

      final summary = AcademicCalculator.calculateGrades(
        grades: grades,
        passingGrade: 8.0,
        gradeScale: 10.0,
      );

      expect(summary.accumulated, 4.5);
      expect(summary.neededOnPending, 8.75);
      expect(summary.status, 'possible');
    });

    // (b) Casos secured, impossible, approved y failed
    test('(b) casos secured, impossible, approved y failed', () {
      // 1. Caso SECURED (ya aseguró la aprobación sacando 0 en lo pendiente)
      final securedGrades = [
        Grade(id: '1', subjectId: 's', name: 'P1', weight: 50.0, score: 10.0), // 5.0 pts
        Grade(id: '2', subjectId: 's', name: 'P2', weight: 40.0, score: 10.0), // 4.0 pts -> total 9.0 pts
        Grade(id: '3', subjectId: 's', name: 'Final', weight: 10.0, score: null),
      ];
      final securedRes = AcademicCalculator.calculateGrades(
        grades: securedGrades,
        passingGrade: 8.0,
        gradeScale: 10.0,
      );
      expect(securedRes.status, 'secured');
      expect(securedRes.neededOnPending! <= 0, isTrue);

      // 2. Caso IMPOSSIBLE (necesitaría más que la calificación máxima)
      final impossibleGrades = [
        Grade(id: '1', subjectId: 's', name: 'P1', weight: 50.0, score: 2.0), // 1.0 pt
        Grade(id: '2', subjectId: 's', name: 'P2', weight: 30.0, score: 2.0), // 0.6 pts -> total 1.6 pts
        Grade(id: '3', subjectId: 's', name: 'Final', weight: 20.0, score: null), // Necesita 6.4 / 0.2 = 32 > 10
      ];
      final impossibleRes = AcademicCalculator.calculateGrades(
        grades: impossibleGrades,
        passingGrade: 8.0,
        gradeScale: 10.0,
      );
      expect(impossibleRes.status, 'impossible');
      expect(impossibleRes.neededOnPending! > 10.0, isTrue);

      // 3. Caso APPROVED (sin pendientes y acumulado >= passingGrade)
      final approvedGrades = [
        Grade(id: '1', subjectId: 's', name: 'P1', weight: 50.0, score: 9.0),
        Grade(id: '2', subjectId: 's', name: 'P2', weight: 50.0, score: 8.0),
      ];
      final approvedRes = AcademicCalculator.calculateGrades(
        grades: approvedGrades,
        passingGrade: 8.0,
        gradeScale: 10.0,
      );
      expect(approvedRes.status, 'approved');
      expect(approvedRes.neededOnPending, isNull);

      // 4. Caso FAILED (sin pendientes y acumulado < passingGrade)
      final failedGrades = [
        Grade(id: '1', subjectId: 's', name: 'P1', weight: 50.0, score: 6.0),
        Grade(id: '2', subjectId: 's', name: 'P2', weight: 50.0, score: 7.0),
      ];
      final failedRes = AcademicCalculator.calculateGrades(
        grades: failedGrades,
        passingGrade: 8.0,
        gradeScale: 10.0,
      );
      expect(failedRes.status, 'failed');
      expect(failedRes.neededOnPending, isNull);
    });

    // (c) Faltas justificadas no cuentan para el límite y aviso en umbral correcto
    test('(c) faltas justificadas no cuentan para el límite y el aviso aparece en el umbral correcto', () {
      // Caso 1: 3 faltas en total, pero 2 justificadas -> injustificadas = 1 de 5.
      final absences1 = [
        Absence(id: '1', subjectId: 'sub-1', date: '2026-11-01', justified: true),
        Absence(id: '2', subjectId: 'sub-1', date: '2026-11-02', justified: true),
        Absence(id: '3', subjectId: 'sub-1', date: '2026-11-03', justified: false),
      ];
      final res1 = AcademicCalculator.calculateAbsences(absences: absences1, maxAbsences: 5);
      expect(res1.count, 3);
      expect(res1.justified, 2);
      expect(res1.remaining, 4); // 5 - 1 = 4
      expect(res1.atRisk, isFalse);
      expect(res1.exceeded, isFalse);

      // Caso 2: 4 faltas injustificadas de 5 -> remaining = 1 (en riesgo)
      final absences2 = [
        Absence(id: '1', subjectId: 'sub-1', date: '2026-11-01', justified: false),
        Absence(id: '2', subjectId: 'sub-1', date: '2026-11-02', justified: false),
        Absence(id: '3', subjectId: 'sub-1', date: '2026-11-03', justified: false),
        Absence(id: '4', subjectId: 'sub-1', date: '2026-11-04', justified: false),
      ];
      final res2 = AcademicCalculator.calculateAbsences(absences: absences2, maxAbsences: 5);
      expect(res2.remaining, 1);
      expect(res2.atRisk, isTrue); // <= 1 falta restante
      expect(res2.exceeded, isFalse);

      // Caso 3: 6 faltas injustificadas de 5 -> límite superado
      final absences3 = [
        ...absences2,
        Absence(id: '5', subjectId: 'sub-1', date: '2026-11-05', justified: false),
        Absence(id: '6', subjectId: 'sub-1', date: '2026-11-06', justified: false),
      ];
      final res3 = AcademicCalculator.calculateAbsences(absences: absences3, maxAbsences: 5);
      expect(res3.remaining, -1);
      expect(res3.exceeded, isTrue);
    });

    // (d) La migración de la versión 2 a la 3 conserva materias, horario y tareas
    test('(d) la migración de la versión 2 a la 3 conserva materias, horario y tareas', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // 1. Crear esquema versión 2
      await DatabaseService.createSubjectsTable(db);
      await DatabaseService.createSchedulesTable(db);
      await DatabaseService.createTasksTable(db);
      await DatabaseService.createSyncMetaTable(db);

      // 2. Insertar registros en versión 2
      final subject = Subject(
        id: 'sub-v2',
        name: 'Sistemas Operativos',
        passingGrade: 8.0,
        gradeScale: 10.0,
      );
      await db.insert('subjects', subject.toDbMap());

      final schedule = Schedule(
        id: 'sch-v2',
        subjectId: 'sub-v2',
        dayOfWeek: 1,
        startTime: '08:00',
        endTime: '10:00',
      );
      await db.insert('schedules', schedule.toDbMap());

      final task = TaskItem(
        id: 'task-v2',
        subjectId: 'sub-v2',
        title: 'Práctica 1 Kernel',
        dueAt: DateTime.now().add(const Duration(days: 2)),
      );
      await db.insert('tasks', task.toDbMap());

      // 3. Ejecutar migración a versión 3 (crea absences y grades)
      await DatabaseService.createAbsencesTable(db);
      await DatabaseService.createGradesTable(db);

      // 4. Verificar que materias, horario y tareas siguen intactos
      final subjectMaps = await db.query('subjects', where: 'id = ?', whereArgs: ['sub-v2']);
      expect(subjectMaps.length, 1);
      expect(subjectMaps.first['name'], 'Sistemas Operativos');

      final scheduleMaps = await db.query('schedules', where: 'id = ?', whereArgs: ['sch-v2']);
      expect(scheduleMaps.length, 1);
      expect(scheduleMaps.first['start_time'], '08:00');

      final taskMaps = await db.query('tasks', where: 'id = ?', whereArgs: ['task-v2']);
      expect(taskMaps.length, 1);
      expect(taskMaps.first['title'], 'Práctica 1 Kernel');

      // 5. Verificar que las nuevas tablas de versión 3 funcionan correctamente
      final absence = Absence(
        id: 'abs-v3',
        subjectId: 'sub-v2',
        date: '2026-11-19',
        justified: false,
      );
      await db.insert('absences', absence.toDbMap());
      final absenceMaps = await db.query('absences', where: 'id = ?', whereArgs: ['abs-v3']);
      expect(absenceMaps.length, 1);

      await db.close();
    });

    // (e) Prueba corrección: una tarea borrada en el sync deja de tener recordatorios programados
    test('(e) una tarea borrada en el sync se elimina de SQLite y cancela recordatorios', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.createTables(db);
      final dbService = DatabaseService.withDatabase(db);

      // 1. Insertar tarea activa
      final activeTask = TaskItem(
        id: 'task-sync-del',
        subjectId: 'sub-1',
        title: 'Tarea a eliminar',
        dueAt: DateTime.now().add(const Duration(days: 1)),
        syncStatus: 'synced',
      );
      await dbService.insertTask(activeTask);

      // 2. Traer versión con deletedAt desde el sync
      final deletedTaskFromSync = TaskItem(
        id: 'task-sync-del',
        subjectId: 'sub-1',
        title: 'Tarea a eliminar',
        dueAt: DateTime.now().add(const Duration(days: 1)),
        deletedAt: DateTime.now().toUtc(),
        syncStatus: 'synced',
      );
      await dbService.upsertTaskFromSync(deletedTaskFromSync);

      // 3. Verificar que se eliminó de la base local y se cancelaron sus recordatorios
      final inDb = await dbService.getTaskById('task-sync-del');
      expect(inDb, isNull);
      expect(NotificationService.instance.lastCancelledTaskIds, contains('task-sync-del'));

      await db.close();
    });

    // (f) Alertas de faltas: claves separadas para en riesgo y superado, y limpieza de claves
    test('(f) claves separadas para en riesgo y superado, y limpieza al descender de umbral', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.createTables(db);
      DatabaseService.instance.database = db;

      final subject = Subject(
        id: 'sub-alerts',
        name: 'Física',
        maxAbsences: 5,
        passingGrade: 8.0,
        gradeScale: 10.0,
      );
      await DatabaseService.instance.insertSubject(subject);

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final warningKey = 'alert_absence_warning_sub-alerts';
      final exceededKey = 'alert_absence_exceeded_sub-alerts';

      final absenceProvider = AbsenceProvider();

      // 1. Agregar 4 faltas injustificadas (en riesgo: restan 1 <= 1)
      for (var i = 1; i <= 4; i++) {
        await absenceProvider.createAbsence(
          subjectId: subject.id,
          date: '2026-11-0$i',
          justified: false,
          subject: subject,
        );
      }

      // Debe activarse aviso de en riesgo, pero NO el de superado
      expect(prefs.getBool(warningKey), isTrue);
      expect(prefs.getBool(exceededKey), isNull);

      // 2. Agregar 2 faltas más para superar el límite (6 de 5)
      await absenceProvider.createAbsence(
        subjectId: subject.id,
        date: '2026-11-05',
        justified: false,
        subject: subject,
      );
      await absenceProvider.createAbsence(
        subjectId: subject.id,
        date: '2026-11-06',
        justified: false,
        subject: subject,
      );

      // Debe activarse aviso de límite superado
      expect(prefs.getBool(exceededKey), isTrue);

      // 3. Justificar una falta (baja a 5 injustificadas, ya no está superado)
      final sixthAbsence = absenceProvider.absences.firstWhere((a) => a.date == '2026-11-06');
      await absenceProvider.toggleJustified(sixthAbsence, subject: subject);

      // La clave de superado debe haber sido eliminada
      expect(prefs.getBool(exceededKey), isNull);

      // 4. Justificar 2 faltas más (baja a 3 injustificadas, ya no está en riesgo)
      final fifthAbsence = absenceProvider.absences.firstWhere((a) => a.date == '2026-11-05');
      await absenceProvider.toggleJustified(fifthAbsence, subject: subject);
      final fourthAbsence = absenceProvider.absences.firstWhere((a) => a.date == '2026-11-04');
      await absenceProvider.toggleJustified(fourthAbsence, subject: subject);

      // La clave de advertencia debe haber sido eliminada
      expect(prefs.getBool(warningKey), isNull);

      await db.close();
    });

    // (g) No se pueden registrar dos faltas el mismo día en la misma materia
    test('(g) no se pueden registrar dos faltas el mismo día en la misma materia', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.createTables(db);
      DatabaseService.instance.database = db;

      final subject = Subject(
        id: 'sub-dup',
        name: 'Química',
        maxAbsences: 5,
        passingGrade: 8.0,
        gradeScale: 10.0,
      );
      await DatabaseService.instance.insertSubject(subject);

      final absenceProvider = AbsenceProvider();

      // 1. Registrar primera falta para hoy
      final ok1 = await absenceProvider.createAbsence(
        subjectId: subject.id,
        date: '2026-11-19',
        justified: false,
        subject: subject,
      );
      expect(ok1, isTrue);
      expect(absenceProvider.absences.length, 1);

      // 2. Intentar registrar una segunda falta en la misma fecha y materia
      final ok2 = await absenceProvider.createAbsence(
        subjectId: subject.id,
        date: '2026-11-19',
        justified: true,
        subject: subject,
      );
      expect(ok2, isFalse);
      expect(absenceProvider.errorMessage, contains('Ya existe una falta registrada para esta fecha'));
      // No debe haberse duplicado
      expect(absenceProvider.absences.length, 1);

      await db.close();
    });
  });
}
