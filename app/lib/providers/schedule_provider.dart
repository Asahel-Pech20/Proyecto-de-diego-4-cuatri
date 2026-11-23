import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class CurrentAndNextClass {
  final Schedule? current;
  final Schedule? next;

  CurrentAndNextClass({this.current, this.next});
}

class ScheduleProvider extends ChangeNotifier {
  List<Schedule> _schedules = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Uuid _uuid = const Uuid();

  List<Schedule> get schedules => _schedules;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadSchedules() async {
    _isLoading = true;
    notifyListeners();

    try {
      _schedules = await DatabaseService.instance.getSchedules();
    } catch (e) {
      _errorMessage = 'Error al cargar horarios: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Schedule> getSchedulesForDay(int dayOfWeek) {
    return _schedules.where((s) => s.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  /// Calcula la clase actual y la clase que sigue a partir de una fecha/hora dada
  static CurrentAndNextClass calculateCurrentAndNext(List<Schedule> allSchedules, DateTime dateTime) {
    final dayOfWeek = dateTime.weekday; // 1 = Lunes ... 7 = Domingo
    final currentMinutes = dateTime.hour * 60 + dateTime.minute;

    final todayClasses = allSchedules.where((s) => s.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    Schedule? currentClass;
    Schedule? nextClass;

    for (final s in todayClasses) {
      if (s.startMinutes <= currentMinutes && currentMinutes < s.endMinutes) {
        currentClass = s;
      } else if (s.startMinutes > currentMinutes) {
        if (nextClass == null || s.startMinutes < nextClass.startMinutes) {
          nextClass = s;
        }
      }
    }

    return CurrentAndNextClass(current: currentClass, next: nextClass);
  }

  CurrentAndNextClass getCurrentAndNextClass({DateTime? at}) {
    return calculateCurrentAndNext(_schedules, at ?? DateTime.now());
  }

  Future<bool> createSchedule({
    required String subjectId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
  }) async {
    _errorMessage = null;

    final schedule = Schedule(
      id: _uuid.v4(),
      subjectId: subjectId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      room: (room == null || room.trim().isEmpty) ? null : room.trim(),
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      syncStatus: 'pending_create',
    );

    // 1. Guardar localmente
    await DatabaseService.instance.insertSchedule(schedule);
    _schedules = await DatabaseService.instance.getSchedules();
    notifyListeners();

    // 2. Intentar subir al servidor
    try {
      final remote = await ApiService.instance.createSchedule(schedule);
      await DatabaseService.instance.insertSchedule(remote.copyWith(syncStatus: 'synced'));
      _schedules = await DatabaseService.instance.getSchedules();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0) {
        return true; // Modo offline exitoso
      }
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al crear horario: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSchedule({
    required String id,
    required String subjectId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
  }) async {
    _errorMessage = null;

    final current = await DatabaseService.instance.getScheduleById(id);
    if (current == null) return false;

    // Construcción explícita para permitir vaciar salón
    final updated = Schedule(
      id: current.id,
      subjectId: subjectId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      room: (room == null || room.trim().isEmpty) ? null : room.trim(),
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      deletedAt: current.deletedAt,
      syncStatus: current.syncStatus == 'pending_create' ? 'pending_create' : 'pending_update',
    );

    // 1. Actualizar localmente
    await DatabaseService.instance.updateSchedule(updated);
    _schedules = await DatabaseService.instance.getSchedules();
    notifyListeners();

    // 2. Subir al servidor
    try {
      final remote = await ApiService.instance.updateSchedule(id, updated.toJson(includeId: false));
      await DatabaseService.instance.updateSchedule(remote.copyWith(syncStatus: 'synced'));
      _schedules = await DatabaseService.instance.getSchedules();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0) {
        return true;
      }
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al actualizar horario: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSchedule(String id) async {
    _errorMessage = null;

    await DatabaseService.instance.markScheduleDeleted(id);
    _schedules = await DatabaseService.instance.getSchedules();
    notifyListeners();

    try {
      await ApiService.instance.deleteSchedule(id);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0 || e.statusCode == 404) return true;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al eliminar clase del horario: $e';
      notifyListeners();
      return false;
    }
  }
}
