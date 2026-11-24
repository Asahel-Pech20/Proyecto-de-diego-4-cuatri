import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/academic_calculator.dart';
import '../models/absence.dart';
import '../models/subject.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AbsenceProvider extends ChangeNotifier {
  List<Absence> _absences = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Uuid _uuid = const Uuid();

  List<Absence> get absences => _absences;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadAbsences(String subjectId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _absences = await DatabaseService.instance.getAbsences(subjectId: subjectId);
    } catch (e) {
      _errorMessage = 'Error al cargar faltas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createAbsence({
    required String subjectId,
    required String date,
    bool justified = false,
    String? note,
    Subject? subject,
  }) async {
    _errorMessage = null;

    // Verificar si ya existe una falta registrada para esa fecha en esta materia
    final alreadyExists = _absences.any((a) => a.subjectId == subjectId && a.date == date);
    if (alreadyExists) {
      _errorMessage = 'Ya existe una falta registrada para esta fecha en esta materia.';
      notifyListeners();
      return false;
    }

    final absence = Absence(
      id: _uuid.v4(),
      subjectId: subjectId,
      date: date,
      justified: justified,
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      syncStatus: 'pending_create',
    );

    // 1. Guardar localmente
    await DatabaseService.instance.insertAbsence(absence);
    _absences = await DatabaseService.instance.getAbsences(subjectId: subjectId);
    notifyListeners();

    // 2. Verificar umbral de faltas y lanzar notificaciones si corresponde (solo al AGREGAR)
    await _checkAndNotifyAbsenceAlerts(subjectId: subjectId, subject: subject);

    // 3. Subir al backend
    try {
      final remote = await ApiService.instance.createAbsence(absence);
      await DatabaseService.instance.insertAbsence(remote.copyWith(syncStatus: 'synced'));
      _absences = await DatabaseService.instance.getAbsences(subjectId: subjectId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0) return true;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al registrar falta: $e';
      notifyListeners();
      return false;
    }
  }

  /// Revisa y lanza alertas inmediatas al AGREGAR una falta
  Future<void> _checkAndNotifyAbsenceAlerts({
    required String subjectId,
    Subject? subject,
  }) async {
    final sub = subject ?? await DatabaseService.instance.getSubjectById(subjectId);
    if (sub == null || sub.maxAbsences == null) return;

    final summary = AcademicCalculator.calculateAbsences(
      absences: _absences,
      maxAbsences: sub.maxAbsences,
    );

    final prefs = await SharedPreferences.getInstance();
    final warningKey = 'alert_absence_warning_${sub.id}';
    final exceededKey = 'alert_absence_exceeded_${sub.id}';

    // 1. Alerta de superado
    if (summary.exceeded) {
      final alreadySentExceeded = prefs.getBool(exceededKey) ?? false;
      if (!alreadySentExceeded) {
        final shown = await NotificationService.instance.showImmediateNotification(
          id: (sub.id.hashCode & 0x7FFFFFFF) + 1,
          title: '¡Límite de faltas superado!',
          body: 'Has excedido el límite de ${sub.maxAbsences} faltas en ${sub.name}.',
        );
        if (shown) await prefs.setBool(exceededKey, true);
      }
    }

    // 2. Alerta de en riesgo
    if (summary.atRisk && !summary.exceeded) {
      final alreadySentWarning = prefs.getBool(warningKey) ?? false;
      if (!alreadySentWarning) {
        final shown = await NotificationService.instance.showImmediateNotification(
          id: sub.id.hashCode & 0x7FFFFFFF,
          title: '¡Atención en ${sub.name}!',
          body: 'Te quedan ${summary.remaining} falta(s) en ${sub.name}.',
        );
        if (shown) await prefs.setBool(warningKey, true);
      }
    }
  }

  /// Limpia las claves de alerta cuando el alumno reduce sus faltas (justificar o borrar).
  /// NUNCA lanza notificaciones.
  Future<void> _cleanAbsenceAlertKeys({
    required String subjectId,
    Subject? subject,
  }) async {
    final sub = subject ?? await DatabaseService.instance.getSubjectById(subjectId);
    if (sub == null || sub.maxAbsences == null) return;

    final summary = AcademicCalculator.calculateAbsences(
      absences: _absences,
      maxAbsences: sub.maxAbsences,
    );

    final prefs = await SharedPreferences.getInstance();
    final warningKey = 'alert_absence_warning_${sub.id}';
    final exceededKey = 'alert_absence_exceeded_${sub.id}';

    // Si ya no está superado, limpiar la clave para permitir avisar en el futuro
    if (!summary.exceeded) {
      await prefs.remove(exceededKey);
    }

    // Si ya no está en riesgo, limpiar la clave de advertencia
    if (!summary.atRisk) {
      await prefs.remove(warningKey);
    }
  }

  Future<void> toggleJustified(Absence absence, {Subject? subject}) async {
    final updated = absence.copyWith(
      justified: !absence.justified,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: absence.syncStatus == 'pending_create' ? 'pending_create' : 'pending_update',
    );

    await DatabaseService.instance.updateAbsence(updated);
    _absences = await DatabaseService.instance.getAbsences(subjectId: absence.subjectId);
    notifyListeners();

    // Al justificar solo se limpian claves si corresponde, nunca se lanzan notificaciones
    await _cleanAbsenceAlertKeys(subjectId: absence.subjectId, subject: subject);

    try {
      await ApiService.instance.updateAbsence(absence.id, {'justified': updated.justified});
      await DatabaseService.instance.updateAbsence(updated.copyWith(syncStatus: 'synced'));
      _absences = await DatabaseService.instance.getAbsences(subjectId: absence.subjectId);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> deleteAbsence(String id, String subjectId, {Subject? subject}) async {
    _errorMessage = null;

    await DatabaseService.instance.markAbsenceDeleted(id);
    _absences = await DatabaseService.instance.getAbsences(subjectId: subjectId);
    notifyListeners();

    // Al borrar solo se limpian claves si corresponde, nunca se lanzan notificaciones
    await _cleanAbsenceAlertKeys(subjectId: subjectId, subject: subject);

    try {
      await ApiService.instance.deleteAbsence(id);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0 || e.statusCode == 404) return true;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al eliminar falta: $e';
      notifyListeners();
      return false;
    }
  }
}
