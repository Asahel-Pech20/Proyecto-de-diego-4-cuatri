import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/subject.dart';
import '../models/subject_summary.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class SubjectProvider extends ChangeNotifier {
  List<Subject> _subjects = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  final Uuid _uuid = const Uuid();

  List<Subject> get subjects => _subjects;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;

  Future<void> loadSubjects({bool triggerSync = true}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Cargar datos locales de inmediato (offline first)
      _subjects = await DatabaseService.instance.getSubjects();
      _isLoading = false;
      notifyListeners();

      // 2. Sincronizar en segundo plano si se solicita
      if (triggerSync) {
        await syncData();
      }
    } catch (e) {
      _errorMessage = 'Error al cargar materias: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncData() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await SyncService.instance.synchronize();
      if (result.success) {
        // Refrescar lista desde la base local actualizada
        _subjects = await DatabaseService.instance.getSubjects();
      }
    } catch (_) {
      // Error silencioso en sincronización periódica
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> createSubject({
    required String name,
    String? teacher,
    String? color,
    int? maxAbsences,
    double passingGrade = 8.0,
    double gradeScale = 10.0,
  }) async {
    _errorMessage = null;

    final newSubject = Subject(
      id: _uuid.v4(),
      name: name.trim(),
      teacher: teacher?.trim().isEmpty == true ? null : teacher?.trim(),
      color: color,
      maxAbsences: maxAbsences,
      passingGrade: passingGrade,
      gradeScale: gradeScale,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      syncStatus: 'pending_create',
    );

    // 1. Guardar de inmediato en local
    await DatabaseService.instance.insertSubject(newSubject);
    _subjects = await DatabaseService.instance.getSubjects();
    notifyListeners();

    // 2. Intentar subir al servidor
    try {
      final remoteSubject = await ApiService.instance.createSubject(newSubject);
      await DatabaseService.instance.insertSubject(
        remoteSubject.copyWith(syncStatus: 'synced'),
      );
      _subjects = await DatabaseService.instance.getSubjects();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0) {
        // Offline: se guardó localmente y se enviará en el siguiente sync
        return true;
      }
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al crear materia: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSubject({
    required String id,
    required String name,
    String? teacher,
    String? color,
    int? maxAbsences,
    required double passingGrade,
    required double gradeScale,
  }) async {
    _errorMessage = null;

    final current = await DatabaseService.instance.getSubjectById(id);
    if (current == null) return false;

    // Construir el Subject explícitamente con los nuevos valores
    // para permitir vaciar campos opcionales (docente, color, límite de faltas).
    final updated = Subject(
      id: id,
      name: name.trim(),
      teacher: (teacher == null || teacher.trim().isEmpty) ? null : teacher.trim(),
      color: (color == null || color.trim().isEmpty) ? null : color.trim(),
      maxAbsences: maxAbsences,
      passingGrade: passingGrade,
      gradeScale: gradeScale,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      deletedAt: current.deletedAt,
      syncStatus: current.syncStatus == 'pending_create' ? 'pending_create' : 'pending_update',
    );

    // 1. Actualizar de inmediato en local
    await DatabaseService.instance.updateSubject(updated);
    _subjects = await DatabaseService.instance.getSubjects();
    notifyListeners();

    // 2. Intentar subir al backend
    try {
      final remoteSubject = await ApiService.instance.updateSubject(
        id,
        updated.toJson(includeId: false),
      );
      await DatabaseService.instance.updateSubject(
        remoteSubject.copyWith(syncStatus: 'synced'),
      );
      _subjects = await DatabaseService.instance.getSubjects();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0) {
        // Offline: queda en cola
        return true;
      }
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al actualizar materia: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSubject(String id) async {
    _errorMessage = null;

    // 1. Marcar/borrar localmente
    await DatabaseService.instance.markSubjectDeleted(id);
    _subjects = await DatabaseService.instance.getSubjects();
    notifyListeners();

    // 2. Intentar borrar en el servidor
    try {
      await ApiService.instance.deleteSubject(id);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0 || e.statusCode == 404) {
        // Offline o ya borrada en el backend
        return true;
      }
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al eliminar materia: $e';
      notifyListeners();
      return false;
    }
  }

  Future<SubjectSummary?> fetchSummary(String id) async {
    try {
      return await ApiService.instance.getSubjectSummary(id);
    } catch (_) {
      return null;
    }
  }
}
