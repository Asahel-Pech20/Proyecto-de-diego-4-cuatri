import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/user.dart';
import 'package:app/models/subject.dart';
import 'package:app/models/subject_summary.dart';
import 'package:app/services/api_service.dart';

void main() {
  group('User Model Tests', () {
    test('User fromJson and toJson', () {
      final json = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'name': 'Ana López',
        'email': 'ana@utm.edu.mx',
        'createdAt': '2026-11-20T14:00:00.000Z',
      };

      final user = User.fromJson(json);
      expect(user.id, '123e4567-e89b-12d3-a456-426614174000');
      expect(user.name, 'Ana López');
      expect(user.email, 'ana@utm.edu.mx');

      final output = user.toJson();
      expect(output['id'], user.id);
      expect(output['name'], 'Ana López');
      expect(output['email'], 'ana@utm.edu.mx');
    });
  });

  group('Subject Model Tests', () {
    test('Subject fromJson and toJson comply with api.md contract', () {
      final json = {
        'id': '987fcdeb-51a2-43f7-9abc-def012345678',
        'name': 'Programación Móvil',
        'teacher': 'Dr. Carlos Hernández',
        'color': '#7A1B29',
        'maxAbsences': 5,
        'passingGrade': 8.0,
        'gradeScale': 10.0,
      };

      final subject = Subject.fromJson(json);
      expect(subject.id, '987fcdeb-51a2-43f7-9abc-def012345678');
      expect(subject.name, 'Programación Móvil');
      expect(subject.teacher, 'Dr. Carlos Hernández');
      expect(subject.color, '#7A1B29');
      expect(subject.maxAbsences, 5);
      expect(subject.passingGrade, 8.0);
      expect(subject.gradeScale, 10.0);

      final exported = subject.toJson();
      expect(exported['name'], 'Programación Móvil');
      expect(exported['teacher'], 'Dr. Carlos Hernández');
      expect(exported['color'], '#7A1B29');
      expect(exported['maxAbsences'], 5);
      expect(exported['passingGrade'], 8.0);
      expect(exported['gradeScale'], 10.0);
    });

    test('Subject clears optional fields when updated with null', () {
      final original = Subject(
        id: 'sub-1',
        name: 'Compiladores',
        teacher: 'Dr. Roberto',
        color: '#7A1B29',
        maxAbsences: 6,
        passingGrade: 8.0,
        gradeScale: 10.0,
      );

      // Reconstruir con campos opcionales vacíos/nulos
      final updated = Subject(
        id: original.id,
        name: 'Compiladores Avanzados',
        teacher: null,
        color: null,
        maxAbsences: null,
        passingGrade: 8.0,
        gradeScale: 10.0,
      );

      expect(updated.teacher, isNull);
      expect(updated.color, isNull);
      expect(updated.maxAbsences, isNull);

      final json = updated.toJson(includeId: false);
      expect(json['name'], 'Compiladores Avanzados');
      expect(json['teacher'], isNull);
      expect(json['color'], isNull);
      expect(json['maxAbsences'], isNull);
    });

    test('Subject toDbMap and fromDbMap SQLite serialization', () {
      final subject = Subject(
        id: 'uuid-1234',
        name: 'Redes de Computadoras',
        teacher: 'Mtro. García',
        color: '#2563EB',
        maxAbsences: 4,
        passingGrade: 8.0,
        gradeScale: 10.0,
        syncStatus: 'pending_create',
      );

      final dbMap = subject.toDbMap();
      expect(dbMap['id'], 'uuid-1234');
      expect(dbMap['name'], 'Redes de Computadoras');
      expect(dbMap['sync_status'], 'pending_create');

      final restored = Subject.fromDbMap(dbMap);
      expect(restored.id, subject.id);
      expect(restored.name, subject.name);
      expect(restored.syncStatus, 'pending_create');
    });
  });

  group('SubjectSummary Model Tests', () {
    test('SubjectSummary parsing from GET /api/subjects/:id/summary contract', () {
      final json = {
        'absences': {
          'count': 4,
          'justified': 0,
          'max': 5,
          'remaining': 1,
          'atRisk': true,
          'exceeded': false,
        },
        'grades': {
          'gradeScale': 10.0,
          'passingGrade': 8.0,
          'gradedWeight': 60.0,
          'pendingWeight': 40.0,
          'totalWeight': 100.0,
          'accumulated': 4.5,
          'currentAverage': 7.5,
          'neededOnPending': 8.75,
          'status': 'possible',
        },
      };

      final summary = SubjectSummary.fromJson(json);
      expect(summary.absences.count, 4);
      expect(summary.absences.atRisk, isTrue);
      expect(summary.absences.remaining, 1);
      expect(summary.grades.accumulated, 4.5);
      expect(summary.grades.currentAverage, 7.5);
      expect(summary.grades.neededOnPending, 8.75);
      expect(summary.grades.status, 'possible');
    });
  });

  group('ApiException Offline Contract Tests', () {
    test('statusCode 0 represents offline/network failure', () {
      final offlineException = ApiException(
        statusCode: 0,
        message: 'No se pudo conectar al servidor.',
      );
      expect(offlineException.statusCode, 0);
      expect(offlineException.message, contains('servidor'));
    });
  });
}
