import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/grade.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class GradeProvider extends ChangeNotifier {
  List<Grade> _grades = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Uuid _uuid = const Uuid();

  List<Grade> get grades => _grades;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get totalWeight => _grades.fold(0.0, (sum, g) => sum + g.weight);
  bool get isWeight100 => (totalWeight - 100.0).abs() < 0.01;

  Future<void> loadGrades(String subjectId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _grades = await DatabaseService.instance.getGrades(subjectId: subjectId);
    } catch (e) {
      _errorMessage = 'Error al cargar calificaciones: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGrade({
    required String subjectId,
    required String name,
    required double weight,
    double? score,
  }) async {
    _errorMessage = null;

    final grade = Grade(
      id: _uuid.v4(),
      subjectId: subjectId,
      name: name.trim(),
      weight: weight,
      score: score,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      syncStatus: 'pending_create',
    );

    // 1. Guardar localmente
    await DatabaseService.instance.insertGrade(grade);
    _grades = await DatabaseService.instance.getGrades(subjectId: subjectId);
    notifyListeners();

    // 2. Subir al backend
    try {
      final remote = await ApiService.instance.createGrade(grade);
      await DatabaseService.instance.insertGrade(remote.copyWith(syncStatus: 'synced'));
      _grades = await DatabaseService.instance.getGrades(subjectId: subjectId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0) return true;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al agregar evaluación: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGrade({
    required String id,
    required String subjectId,
    required String name,
    required double weight,
    double? score,
  }) async {
    _errorMessage = null;

    final current = await DatabaseService.instance.getGradeById(id);
    if (current == null) return false;

    // Construcción explícita para permitir vaciar score (null = pendiente)
    final updated = Grade(
      id: current.id,
      subjectId: subjectId,
      name: name.trim(),
      weight: weight,
      score: score,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      deletedAt: current.deletedAt,
      syncStatus: current.syncStatus == 'pending_create' ? 'pending_create' : 'pending_update',
    );

    // 1. Guardar localmente
    await DatabaseService.instance.updateGrade(updated);
    _grades = await DatabaseService.instance.getGrades(subjectId: subjectId);
    notifyListeners();

    // 2. Subir al backend
    try {
      final remote = await ApiService.instance.updateGrade(id, updated.toJson(includeId: false));
      await DatabaseService.instance.updateGrade(remote.copyWith(syncStatus: 'synced'));
      _grades = await DatabaseService.instance.getGrades(subjectId: subjectId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0) return true;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al actualizar evaluación: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGrade(String id, String subjectId) async {
    _errorMessage = null;

    await DatabaseService.instance.markGradeDeleted(id);
    _grades = await DatabaseService.instance.getGrades(subjectId: subjectId);
    notifyListeners();

    try {
      await ApiService.instance.deleteGrade(id);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0 || e.statusCode == 404) return true;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al eliminar evaluación: $e';
      notifyListeners();
      return false;
    }
  }
}
