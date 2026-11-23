import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app/models/subject.dart';
import 'package:app/services/api_service.dart';
import 'package:app/services/database_service.dart';
import 'package:app/providers/subject_provider.dart';

class MockSocketExceptionClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw const SocketException('Failed host lookup: api.utm.edu.mx');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();

    // Mock para flutter_secure_storage en ambiente de pruebas unitarias
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'read') return 'mock_token';
        if (methodCall.method == 'write') return null;
        if (methodCall.method == 'delete') return null;
        return null;
      },
    );
  });

  group('Manejo de Errores de Red y Sincronización Offline', () {
    // (a) Una petición que lanza SocketException se convierte en ApiException con statusCode 0
    test('(a) una petición que lanza SocketException se convierte en ApiException con statusCode 0', () async {
      final mockClient = MockSocketExceptionClient();
      final api = ApiService(client: mockClient);

      // Probar petición autenticada (GET /api/subjects)
      try {
        await api.getSubjects();
        fail('Se esperaba que lanzara ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 0);
        expect(e.message, 'Sin conexión con el servidor');
      }

      // Probar petición no autenticada (POST /api/auth/login)
      try {
        await api.login(email: 'ana@utm.edu.mx', password: 'password123');
        fail('Se esperaba que lanzara ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 0);
        expect(e.message, 'Sin conexión con el servidor');
      }

      // Probar petición POST de creación (POST /api/subjects)
      try {
        await api.createSubject(Subject(
          id: 'test-uuid',
          name: 'Programación',
          passingGrade: 8.0,
          gradeScale: 10.0,
        ));
        fail('Se esperaba que lanzara ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 0);
        expect(e.message, 'Sin conexión con el servidor');
      }
    });

    // (b) upsertSubjectFromSync no sobrescribe una fila con estado pending_update
    test('(b) upsertSubjectFromSync no sobrescribe una fila con estado pending_update', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.createTables(db);
      final dbService = DatabaseService.withDatabase(db);

      // Fila local con cambios pendientes de sincronizar
      final localPending = Subject(
        id: 'subject-100',
        name: 'Materia Editada Local',
        teacher: 'Profesor Local',
        color: '#2563EB',
        maxAbsences: 3,
        passingGrade: 8.0,
        gradeScale: 10.0,
        syncStatus: 'pending_update',
      );
      await dbService.insertSubject(localPending);

      // Simular que el servidor manda una versión anterior
      final serverSubject = Subject(
        id: 'subject-100',
        name: 'Materia Servidor Antigua',
        teacher: 'Profesor Antiguo',
        color: '#7A1B29',
        maxAbsences: 5,
        passingGrade: 8.0,
        gradeScale: 10.0,
        syncStatus: 'synced',
      );

      // Ejecutar upsertSubjectFromSync
      await dbService.upsertSubjectFromSync(serverSubject);

      // Verificar que NO se sobrescribió
      final result = await dbService.getSubjectById('subject-100');
      expect(result, isNotNull);
      expect(result!.name, 'Materia Editada Local');
      expect(result.teacher, 'Profesor Local');
      expect(result.maxAbsences, 3);
      expect(result.syncStatus, 'pending_update');

      await db.close();
    });

    // (c) Editar una materia dejando maxAbsences en null la guarda como null
    test('(c) editar una materia dejando maxAbsences en null la guarda como null', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await DatabaseService.createTables(db);
      DatabaseService.instance.database = db;

      // 1. Materia con maxAbsences = 5
      final originalSubject = Subject(
        id: 'subject-200',
        name: 'Cálculo Avanzado',
        teacher: 'Dr. Morales',
        color: '#7A1B29',
        maxAbsences: 5,
        passingGrade: 8.0,
        gradeScale: 10.0,
        syncStatus: 'synced',
      );
      await DatabaseService.instance.insertSubject(originalSubject);

      // 2. Actualizar dejando maxAbsences en null
      final provider = SubjectProvider();
      await provider.updateSubject(
        id: 'subject-200',
        name: 'Cálculo Avanzado Modificado',
        teacher: 'Dr. Morales',
        color: '#7A1B29',
        maxAbsences: null, // Dejando en null
        passingGrade: 8.0,
        gradeScale: 10.0,
      );

      // 3. Verificar en SQLite
      final inDb = await DatabaseService.instance.getSubjectById('subject-200');
      expect(inDb, isNotNull);
      expect(inDb!.maxAbsences, isNull);
      expect(inDb.name, 'Cálculo Avanzado Modificado');

      // 4. Verificar en el estado del provider
      final inProvider = provider.subjects.firstWhere((s) => s.id == 'subject-200');
      expect(inProvider.maxAbsences, isNull);

      await db.close();
    });
  });
}
