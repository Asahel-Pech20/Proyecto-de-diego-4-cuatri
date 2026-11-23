import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/models/schedule.dart';
import 'package:app/models/subject.dart';
import 'package:app/models/task_item.dart';
import 'package:app/providers/schedule_provider.dart';
import 'package:app/providers/task_provider.dart';
import 'package:app/services/api_service.dart';
import 'package:app/services/database_service.dart';
import 'package:app/services/notification_service.dart';
import 'package:app/services/sync_service.dart';

class OrderTrackingClient extends http.BaseClient {
  final List<String> requestLog = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestLog.add('${request.method} ${request.url.path}');

    if (request.url.path == '/api/subjects' && request.method == 'POST') {
      final body = jsonEncode({
        'id': 'sub-new',
        'name': 'Materia Nueva',
        'passingGrade': 8.0,
        'gradeScale': 10.0,
      });
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 201);
    }

    if (request.url.path == '/api/tasks' && request.method == 'POST') {
      final body = jsonEncode({
        'id': 'task-new',
        'subjectId': 'sub-new',
        'title': 'Tarea Nueva',
        'dueAt': DateTime.now().toUtc().toIso8601String(),
        'done': false,
        'reminders': [1440, 120],
      });
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 201);
    }

    if (request.url.path == '/api/sync') {
      final body = jsonEncode({
        'serverTime': '2026-11-19T20:00:00.000Z',
        'subjects': [],
        'schedules': [],
        'tasks': [],
      });
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
    }

    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
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

  group('Pruebas del nuevo bloque (Horario, Tareas, Notificaciones y Sync)', () {
    // (a) La agrupación de tareas por fecha
    test('(a) la agrupación de tareas por fecha', () {
      final refDate = DateTime(2026, 11, 18, 10, 0); // Miércoles 10:00

      final tasks = [
        TaskItem(
          id: '1',
          subjectId: 'sub-1',
          title: 'Vencida',
          dueAt: DateTime(2026, 11, 17, 14, 0), // Ayer
          done: false,
        ),
        TaskItem(
          id: '2',
          subjectId: 'sub-1',
          title: 'Para Hoy',
          dueAt: DateTime(2026, 11, 18, 18, 0), // Hoy a las 18:00
          done: false,
        ),
        TaskItem(
          id: '3',
          subjectId: 'sub-1',
          title: 'Para Mañana',
          dueAt: DateTime(2026, 11, 19, 11, 0), // Mañana
          done: false,
        ),
        TaskItem(
          id: '4',
          subjectId: 'sub-1',
          title: 'Esta Semana',
          dueAt: DateTime(2026, 11, 21, 15, 0), // Sábado de esta semana
          done: false,
        ),
        TaskItem(
          id: '5',
          subjectId: 'sub-1',
          title: 'Después',
          dueAt: DateTime(2026, 11, 25, 10, 0), // Siguiente semana
          done: false,
        ),
        TaskItem(
          id: '6',
          subjectId: 'sub-1',
          title: 'Completada',
          dueAt: DateTime(2026, 11, 16, 10, 0),
          done: true,
        ),
      ];

      final grouped = TaskProvider.groupTasks(tasks, now: refDate);

      expect(grouped.overdue.map((t) => t.id), ['1']);
      expect(grouped.today.map((t) => t.id), ['2']);
      expect(grouped.tomorrow.map((t) => t.id), ['3']);
      expect(grouped.thisWeek.map((t) => t.id), ['4']);
      expect(grouped.later.map((t) => t.id), ['5']);
      expect(grouped.completed.map((t) => t.id), ['6']);
    });

    // (b) El cálculo de "qué clase sigue" a partir del horario y una hora dada
    test('(b) el cálculo de qué clase sigue a partir del horario y una hora dada', () {
      final schedules = [
        Schedule(
          id: 'c1',
          subjectId: 'sub-1',
          dayOfWeek: 3, // Miércoles
          startTime: '08:00',
          endTime: '10:00',
          room: 'A-1',
        ),
        Schedule(
          id: 'c2',
          subjectId: 'sub-2',
          dayOfWeek: 3, // Miércoles
          startTime: '10:00',
          endTime: '12:00',
          room: 'Lab-2',
        ),
        Schedule(
          id: 'c3',
          subjectId: 'sub-3',
          dayOfWeek: 3, // Miércoles
          startTime: '14:00',
          endTime: '16:00',
          room: 'B-3',
        ),
        Schedule(
          id: 'c4',
          subjectId: 'sub-4',
          dayOfWeek: 4, // Jueves (no debe afectar hoy)
          startTime: '08:00',
          endTime: '10:00',
        ),
      ];

      // Caso 1: En curso a las 09:15 de un miércoles (weekday = 3)
      // 2026-11-18 fue miércoles
      final timeDuringClass1 = DateTime(2026, 11, 18, 9, 15);
      final res1 = ScheduleProvider.calculateCurrentAndNext(schedules, timeDuringClass1);
      expect(res1.current, isNotNull);
      expect(res1.current!.id, 'c1');
      expect(res1.next, isNotNull);
      expect(res1.next!.id, 'c2');

      // Caso 2: Entre clases a las 12:30 del miércoles
      final timeBetweenClasses = DateTime(2026, 11, 18, 12, 30);
      final res2 = ScheduleProvider.calculateCurrentAndNext(schedules, timeBetweenClasses);
      expect(res2.current, isNull);
      expect(res2.next, isNotNull);
      expect(res2.next!.id, 'c3');

      // Caso 3: Después de todas las clases del día (17:00)
      final timeAfterClasses = DateTime(2026, 11, 18, 17, 0);
      final res3 = ScheduleProvider.calculateCurrentAndNext(schedules, timeAfterClasses);
      expect(res3.current, isNull);
      expect(res3.next, isNull);
    });

    // (c) El cálculo de las fechas de recordatorio (incluyendo que no se programen las que ya pasaron)
    test('(c) el cálculo de las fechas de recordatorio excluyendo las que ya pasaron', () {
      final dueAt = DateTime(2026, 11, 20, 14, 0); // Viernes 14:00
      final reminders = [2880, 1440, 120, 10]; // 2 días, 1 día, 2 h, 10 min

      // Si ahora es Jueves 16:00 (2026-11-19 16:00)
      // dueAt - 2880 min = Miércoles 14:00 (ya pasó)
      // dueAt - 1440 min = Jueves 14:00 (ya pasó)
      // dueAt - 120 min = Viernes 12:00 (futuro)
      // dueAt - 10 min = Viernes 13:50 (futuro)
      final now = DateTime(2026, 11, 19, 16, 0);

      final scheduledTimes = NotificationService.calculateReminderTimes(
        dueAt,
        reminders,
        now: now,
      );

      expect(scheduledTimes.length, 2);
      expect(scheduledTimes[0], DateTime(2026, 11, 20, 12, 0));
      expect(scheduledTimes[1], DateTime(2026, 11, 20, 13, 50));
    });

    // (d) Que una tarea pending_create cuya materia también es pending_create se envía después de la materia
    test('(d) una tarea pending_create cuya materia también es pending_create se envía después de la materia', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.createTables(db);
      DatabaseService.instance.database = db;

      final trackingClient = OrderTrackingClient();
      ApiService.instance.client = trackingClient;

      // Materia pendiente de creación
      final pendingSubject = Subject(
        id: 'sub-new',
        name: 'Materia Nueva',
        passingGrade: 8.0,
        gradeScale: 10.0,
        syncStatus: 'pending_create',
      );
      await DatabaseService.instance.insertSubject(pendingSubject);

      // Tarea pendiente de creación que depende de la materia
      final pendingTask = TaskItem(
        id: 'task-new',
        subjectId: 'sub-new',
        title: 'Tarea Nueva',
        dueAt: DateTime.now().add(const Duration(days: 1)),
        done: false,
        syncStatus: 'pending_create',
      );
      await DatabaseService.instance.insertTask(pendingTask);

      // Ejecutar sincronización
      final syncResult = await SyncService.instance.synchronize();
      expect(syncResult.success, isTrue, reason: 'Sync falló con: ${syncResult.error}');

      // Verificar orden de llamadas HTTP
      final subjectPostIndex = trackingClient.requestLog.indexOf('POST /api/subjects');
      final taskPostIndex = trackingClient.requestLog.indexOf('POST /api/tasks');

      expect(subjectPostIndex, isNot(-1));
      expect(taskPostIndex, isNot(-1));
      expect(
        subjectPostIndex < taskPostIndex,
        isTrue,
        reason: 'POST /api/subjects debe ejecutarse antes que POST /api/tasks',
      );

      await db.close();
    });
  });
}
