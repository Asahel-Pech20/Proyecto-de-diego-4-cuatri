import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task_item.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class GroupedTasks {
  final List<TaskItem> overdue;
  final List<TaskItem> today;
  final List<TaskItem> tomorrow;
  final List<TaskItem> thisWeek;
  final List<TaskItem> later;
  final List<TaskItem> completed;

  GroupedTasks({
    required this.overdue,
    required this.today,
    required this.tomorrow,
    required this.thisWeek,
    required this.later,
    required this.completed,
  });

  bool get isEmpty =>
      overdue.isEmpty &&
      today.isEmpty &&
      tomorrow.isEmpty &&
      thisWeek.isEmpty &&
      later.isEmpty &&
      completed.isEmpty;
}

class TaskProvider extends ChangeNotifier {
  List<TaskItem> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Uuid _uuid = const Uuid();

  List<TaskItem> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await DatabaseService.instance.getTasks();
    } catch (e) {
      _errorMessage = 'Error al cargar tareas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Agrupa las tareas según su fecha de vencimiento relativo a la fecha de referencia
  static GroupedTasks groupTasks(List<TaskItem> allTasks, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final todayStart = DateTime(reference.year, reference.month, reference.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final dayAfterTomorrowStart = todayStart.add(const Duration(days: 2));

    // Fin de la semana en curso (domingo a las 23:59:59)
    // En Dart weekday 1=Lunes, 7=Domingo
    final daysUntilSunday = 7 - reference.weekday;
    final endOfWeek = DateTime(
      reference.year,
      reference.month,
      reference.day,
      23,
      59,
      59,
    ).add(Duration(days: daysUntilSunday));

    final List<TaskItem> overdue = [];
    final List<TaskItem> today = [];
    final List<TaskItem> tomorrow = [];
    final List<TaskItem> thisWeek = [];
    final List<TaskItem> later = [];
    final List<TaskItem> completed = [];

    for (final task in allTasks) {
      if (task.done) {
        completed.add(task);
        continue;
      }

      final taskDue = task.dueAt.toLocal();

      if (taskDue.isBefore(reference)) {
        overdue.add(task);
      } else if (taskDue.isBefore(tomorrowStart)) {
        today.add(task);
      } else if (taskDue.isBefore(dayAfterTomorrowStart)) {
        tomorrow.add(task);
      } else if (taskDue.isBefore(endOfWeek) || taskDue.isAtSameMomentAs(endOfWeek)) {
        thisWeek.add(task);
      } else {
        later.add(task);
      }
    }

    return GroupedTasks(
      overdue: overdue,
      today: today,
      tomorrow: tomorrow,
      thisWeek: thisWeek,
      later: later,
      completed: completed,
    );
  }

  GroupedTasks get groupedTasks => groupTasks(_tasks);

  Future<bool> createTask({
    required String subjectId,
    required String title,
    String? description,
    required DateTime dueAt,
    String kind = 'task',
    File? photoFile,
    List<int> reminders = const [1440, 120],
    String subjectName = 'Materia',
  }) async {
    _errorMessage = null;

    final localPhotoPath = photoFile?.path;

    final task = TaskItem(
      id: _uuid.v4(),
      subjectId: subjectId,
      kind: kind,
      title: title.trim(),
      description: (description == null || description.trim().isEmpty) ? null : description.trim(),
      dueAt: dueAt.toUtc(),
      done: false,
      photoUrl: null,
      localPhotoPath: localPhotoPath,
      reminders: reminders,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      syncStatus: 'pending_create',
    );

    // 1. Guardar localmente de inmediato (offline first: cierra modal sin esperar subida)
    await DatabaseService.instance.insertTask(task);
    _tasks = await DatabaseService.instance.getTasks();
    notifyListeners();

    // 2. Programar notificaciones locales
    await NotificationService.instance.scheduleTaskReminders(task, subjectName);

    // 3. Subir foto y enviar al backend en segundo plano
    _syncTaskInBackground(task, photoFile);

    return true;
  }

  Future<void> _syncTaskInBackground(TaskItem initialTask, File? photoFile) async {
    var task = initialTask;

    if (photoFile != null && await photoFile.exists()) {
      try {
        final uploadedUrl = await ApiService.instance.uploadPhoto(photoFile);
        task = task.copyWith(photoUrl: uploadedUrl, clearLocalPhotoPath: true);
        await DatabaseService.instance.updateTask(task);
        _tasks = await DatabaseService.instance.getTasks();
        notifyListeners();
      } catch (e) {
        debugPrint('Subida de foto en segundo plano pospuesta para sync: $e');
      }
    }

    try {
      final remote = await ApiService.instance.createTask(task);
      await DatabaseService.instance.insertTask(
        remote.copyWith(
          syncStatus: 'synced',
          localPhotoPath: task.photoUrl != null ? null : task.localPhotoPath,
        ),
      );
      _tasks = await DatabaseService.instance.getTasks();
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode != 0) {
        debugPrint('Error del servidor al crear tarea en segundo plano: ${e.message}');
      }
    } catch (e) {
      debugPrint('Error creando tarea en segundo plano: $e');
    }
  }

  Future<bool> updateTask({
    required String id,
    required String subjectId,
    required String title,
    String? description,
    required DateTime dueAt,
    required String kind,
    String? photoUrl,
    String? localPhotoPath,
    List<int> reminders = const [1440, 120],
    required bool done,
    String subjectName = 'Materia',
  }) async {
    _errorMessage = null;

    final current = await DatabaseService.instance.getTaskById(id);
    if (current == null) return false;

    // Construcción explícita para permitir vaciar campos opcionales
    final updated = TaskItem(
      id: current.id,
      subjectId: subjectId,
      kind: kind,
      title: title.trim(),
      description: (description == null || description.trim().isEmpty) ? null : description.trim(),
      dueAt: dueAt.toUtc(),
      done: done,
      photoUrl: photoUrl,
      localPhotoPath: localPhotoPath ?? current.localPhotoPath,
      reminders: reminders,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      deletedAt: current.deletedAt,
      syncStatus: current.syncStatus == 'pending_create' ? 'pending_create' : 'pending_update',
    );

    // 1. Guardar localmente de inmediato
    await DatabaseService.instance.updateTask(updated);
    _tasks = await DatabaseService.instance.getTasks();
    notifyListeners();

    // 2. Actualizar recordatorios
    if (done) {
      await NotificationService.instance.cancelTaskReminders(id);
    } else {
      await NotificationService.instance.scheduleTaskReminders(updated, subjectName);
    }

    // 3. Subir al backend en segundo plano
    _syncUpdatedTaskInBackground(updated, localPhotoPath != null ? File(localPhotoPath) : null);

    return true;
  }

  Future<void> _syncUpdatedTaskInBackground(TaskItem taskToUpdate, File? photoFile) async {
    var task = taskToUpdate;

    if (photoFile != null && await photoFile.exists() && (task.photoUrl == null || task.photoUrl!.isEmpty)) {
      try {
        final uploadedUrl = await ApiService.instance.uploadPhoto(photoFile);
        task = task.copyWith(photoUrl: uploadedUrl, clearLocalPhotoPath: true);
        await DatabaseService.instance.updateTask(task);
        _tasks = await DatabaseService.instance.getTasks();
        notifyListeners();
      } catch (e) {
        debugPrint('Subida de foto en segundo plano pospuesta para sync: $e');
      }
    }

    try {
      final remote = await ApiService.instance.updateTask(task.id, task.toJson(includeId: false));
      await DatabaseService.instance.updateTask(
        remote.copyWith(
          syncStatus: 'synced',
          localPhotoPath: task.photoUrl != null ? null : task.localPhotoPath,
        ),
      );
      _tasks = await DatabaseService.instance.getTasks();
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode != 0) {
        debugPrint('Error del servidor al actualizar tarea en segundo plano: ${e.message}');
      }
    } catch (e) {
      debugPrint('Error actualizando tarea en segundo plano: $e');
    }
  }

  Future<void> toggleDone(TaskItem task, {String subjectName = 'Materia'}) async {
    final newDone = !task.done;
    final updated = task.copyWith(
      done: newDone,
      updatedAt: DateTime.now().toUtc(),
      syncStatus: task.syncStatus == 'pending_create' ? 'pending_create' : 'pending_update',
    );

    // 1. Local de inmediato
    await DatabaseService.instance.updateTask(updated);
    _tasks = await DatabaseService.instance.getTasks();
    notifyListeners();

    // 2. Recordatorios
    if (newDone) {
      await NotificationService.instance.cancelTaskReminders(task.id);
    } else {
      await NotificationService.instance.scheduleTaskReminders(updated, subjectName);
    }

    // 3. Servidor
    try {
      await ApiService.instance.updateTask(task.id, {'done': newDone});
      await DatabaseService.instance.updateTask(updated.copyWith(syncStatus: 'synced'));
      _tasks = await DatabaseService.instance.getTasks();
      notifyListeners();
    } catch (_) {
      // Si falla o está offline, queda en pending_update y se enviará en sync
    }
  }

  Future<bool> deleteTask(String id) async {
    _errorMessage = null;

    await DatabaseService.instance.markTaskDeleted(id);
    _tasks = await DatabaseService.instance.getTasks();
    notifyListeners();

    await NotificationService.instance.cancelTaskReminders(id);

    try {
      await ApiService.instance.deleteTask(id);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 0 || e.statusCode == 404) return true;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al eliminar tarea: $e';
      notifyListeners();
      return false;
    }
  }
}
