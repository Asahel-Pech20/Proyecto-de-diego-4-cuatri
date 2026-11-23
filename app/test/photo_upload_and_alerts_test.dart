import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app/models/subject.dart';
import 'package:app/models/task_item.dart';
import 'package:app/providers/absence_provider.dart';
import 'package:app/services/api_service.dart';
import 'package:app/services/database_service.dart';
import 'package:app/services/notification_service.dart';
import 'package:app/services/sync_service.dart';

class RequestCapturingClient extends http.BaseClient {
  final List<http.BaseRequest> capturedRequests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    capturedRequests.add(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'url': '/api/uploads/sample.jpg'}))),
      201,
    );
  }
}

class MockSyncWithPhotoClient extends http.BaseClient {
  final List<String> calls = [];
  Map<String, dynamic>? patchedBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls.add('${request.method} ${request.url.path}');

    if (request.method == 'POST' && request.url.path == '/api/uploads') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'url': '/api/uploads/uploaded_pizarron.jpg'}))),
        201,
      );
    }

    if (request.method == 'PATCH' && request.url.path.startsWith('/api/tasks/')) {
      if (request is http.Request) {
        patchedBody = jsonDecode(request.body);
      }
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'id': 'task-pizarron',
          'subjectId': 'sub-pizarron',
          'title': 'Foto del pizarron',
          'dueAt': DateTime.now().toUtc().toIso8601String(),
          'done': false,
          'photoUrl': '/api/uploads/uploaded_pizarron.jpg',
          'reminders': [1440, 120],
          'createdAt': '2026-11-19T10:00:00Z',
          'updatedAt': '2026-11-19T10:00:00Z',
        }))),
        200,
      );
    }

    if (request.url.path == '/api/sync') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'serverTime': '2026-11-19T20:00:00.000Z',
          'subjects': [],
          'schedules': [],
          'tasks': [],
          'absences': [],
          'grades': [],
        }))),
        200,
      );
    }

    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }
}

class MockAbsenceUploadClient extends http.BaseClient {
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
          'subjectId': parsed['subjectId'] ?? 'sub-del-alerts',
          'date': parsed['date'] ?? '2026-11-01',
          'justified': parsed['justified'] ?? false,
          'createdAt': '2026-11-19T10:00:00Z',
          'updatedAt': '2026-11-19T10:00:00Z',
        }))),
        201,
      );
    }

    if (request.method == 'DELETE' && request.url.path.startsWith('/api/absences/')) {
      return http.StreamedResponse(Stream.value(utf8.encode('')), 204);
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

  group('Revisión Claude - Fotos, Sincronización y Alertas de Faltas', () {
    // (a) uploadPhoto manda Content-Type image/jpeg para un .jpg e image/png para un .png
    test('(a) uploadPhoto manda Content-Type image/jpeg para un .jpg e image/png para un .png', () async {
      final tempDir = Directory.systemTemp.createTempSync('photos_test_');
      final jpgFile = File('${tempDir.path}/pizarron.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      final pngFile = File('${tempDir.path}/captura.png')..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);

      final capturingClient = RequestCapturingClient();
      final api = ApiService(client: capturingClient);

      // 1. Subir archivo .jpg
      await api.uploadPhoto(jpgFile);
      final jpgReq = capturingClient.capturedRequests.last as http.MultipartRequest;
      expect(jpgReq.files.first.contentType.mimeType, 'image/jpeg');
      expect(jpgReq.files.first.field, 'photo');

      // 2. Subir archivo .png
      await api.uploadPhoto(pngFile);
      final pngReq = capturingClient.capturedRequests.last as http.MultipartRequest;
      expect(pngReq.files.first.contentType.mimeType, 'image/png');
      expect(pngReq.files.first.field, 'photo');

      tempDir.deleteSync(recursive: true);
    });

    // (b) una tarea 'synced' con local_photo_path y photo_url null sube la foto y hace PATCH en el siguiente sync
    test('(b) una tarea synced con local_photo_path y photo_url null sube la foto y hace PATCH en el siguiente sync', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.createTables(db);
      DatabaseService.instance.database = db;

      final tempDir = Directory.systemTemp.createTempSync('sync_photo_test_');
      final localPhoto = File('${tempDir.path}/pizarron_local.jpg')..writeAsBytesSync([1, 2, 3]);

      // Insertar tarea 'synced' que no tiene photoUrl pero sí localPhotoPath
      final task = TaskItem(
        id: 'task-pizarron',
        subjectId: 'sub-pizarron',
        title: 'Foto del pizarron',
        dueAt: DateTime.now().add(const Duration(days: 1)),
        photoUrl: null,
        localPhotoPath: localPhoto.path,
        syncStatus: 'synced',
      );
      await db.insert('tasks', task.toDbMap());

      final mockClient = MockSyncWithPhotoClient();
      ApiService.instance.client = mockClient;

      // Ejecutar sincronización
      final syncResult = await SyncService.instance.synchronize();
      expect(syncResult.success, isTrue);

      // Verificar que se subió la foto y se hizo PATCH de photoUrl
      expect(mockClient.calls, contains('POST /api/uploads'));
      expect(mockClient.calls, contains('PATCH /api/tasks/task-pizarron'));
      expect(mockClient.patchedBody?['photoUrl'], '/api/uploads/uploaded_pizarron.jpg');

      // Verificar en base de datos local que ahora tiene photoUrl y se borró localPhotoPath
      final updatedTaskInDb = await DatabaseService.instance.getTaskById('task-pizarron');
      expect(updatedTaskInDb, isNotNull);
      expect(updatedTaskInDb!.photoUrl, '/api/uploads/uploaded_pizarron.jpg');
      expect(updatedTaskInDb.localPhotoPath, isNull);

      tempDir.deleteSync(recursive: true);
      await db.close();
    });

    // (c) borrar una falta no lanza notificaciones
    test('(c) borrar una falta no lanza notificaciones', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.createTables(db);
      DatabaseService.instance.database = db;

      final subject = Subject(
        id: 'sub-del-alerts',
        name: 'Matemáticas',
        maxAbsences: 5,
        passingGrade: 8.0,
        gradeScale: 10.0,
      );
      await DatabaseService.instance.insertSubject(subject);

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      ApiService.instance.client = MockAbsenceUploadClient();
      final provider = AbsenceProvider();

      // 1. Agregar 6 faltas injustificadas para superar el límite (6 de 5)
      for (var i = 1; i <= 6; i++) {
        await provider.createAbsence(
          subjectId: subject.id,
          date: '2026-11-0$i',
          justified: false,
          subject: subject,
        );
      }

      // Debe haber lanzado notificaciones inmediatas al AGREGAR
      expect(NotificationService.instance.lastImmediateNotifications.isNotEmpty, isTrue);
      final countBeforeDelete = NotificationService.instance.lastImmediateNotifications.length;

      // Clave de superado debe estar en true
      expect(prefs.getBool('alert_absence_exceeded_${subject.id}'), isTrue);

      // 2. BORRAR la 6ta falta (baja a 5 injustificadas, es decir, 'en riesgo')
      final sixthAbsence = provider.absences.firstWhere((a) => a.date == '2026-11-06');
      await provider.deleteAbsence(sixthAbsence.id, subject.id, subject: subject);

      // 3. VERIFICAR QUE NO SE LANZARON NOTIFICACIONES AL BORRAR
      expect(NotificationService.instance.lastImmediateNotifications.length, countBeforeDelete);

      // 4. Verificar que la clave de superado fue limpiada de SharedPreferences
      expect(prefs.getBool('alert_absence_exceeded_${subject.id}'), isNull);

      await db.close();
    });
  });
}
