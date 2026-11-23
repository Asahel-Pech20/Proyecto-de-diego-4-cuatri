import 'dart:developer' as developer;
import 'dart:io';
import '../models/subject.dart';
import '../models/schedule.dart';
import '../models/task_item.dart';
import '../models/absence.dart';
import '../models/grade.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'storage_service.dart';

class SyncResult {
  final bool success;
  final bool isOffline;
  final String? error;

  SyncResult({
    required this.success,
    this.isOffline = false,
    this.error,
  });
}

class SyncService {
  static SyncService? _instance;
  void Function()? onSyncCompleted;

  SyncService();
  SyncService._();

  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }

  static set instance(SyncService service) => _instance = service;

  Future<SyncResult> synchronize() async {
    try {
      // ========================================================
      // 1. ENVIAR CAMBIOS PENDIENTES LOCALES
      // Orden: Materias -> Horario -> Tareas -> Faltas -> Calificaciones
      // ========================================================

      // 1.1 Materias
      final pendingSubjects = await DatabaseService.instance.getPendingSubjects();
      for (final subject in pendingSubjects) {
        if (subject.syncStatus == 'pending_create') {
          try {
            await ApiService.instance.createSubject(subject);
            await DatabaseService.instance.insertSubject(subject.copyWith(syncStatus: 'synced'));
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            if (e.statusCode == 409) {
              await DatabaseService.instance.insertSubject(subject.copyWith(syncStatus: 'synced'));
            } else {
              developer.log('Error del servidor al crear materia ${subject.id}: $e');
            }
          } catch (e) {
            developer.log('Error inesperado al crear materia ${subject.id}: $e');
          }
        } else if (subject.syncStatus == 'pending_update') {
          try {
            await ApiService.instance.updateSubject(subject.id, subject.toJson(includeId: false));
            await DatabaseService.instance.updateSubject(subject.copyWith(syncStatus: 'synced'));
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            developer.log('Error del servidor al actualizar materia ${subject.id}: $e');
          } catch (e) {
            developer.log('Error inesperado al actualizar materia ${subject.id}: $e');
          }
        } else if (subject.syncStatus == 'pending_delete') {
          try {
            await ApiService.instance.deleteSubject(subject.id);
            await DatabaseService.instance.hardDeleteSubject(subject.id);
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            if (e.statusCode == 404) {
              await DatabaseService.instance.hardDeleteSubject(subject.id);
            } else {
              developer.log('Error del servidor al borrar materia ${subject.id}: $e');
            }
          } catch (e) {
            developer.log('Error inesperado al borrar materia ${subject.id}: $e');
          }
        }
      }

      // 1.2 Horarios (Schedules)
      final pendingSchedules = await DatabaseService.instance.getPendingSchedules();
      for (final schedule in pendingSchedules) {
        if (schedule.syncStatus == 'pending_create') {
          try {
            await ApiService.instance.createSchedule(schedule);
            await DatabaseService.instance.insertSchedule(schedule.copyWith(syncStatus: 'synced'));
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            if (e.statusCode == 409) {
              await DatabaseService.instance.insertSchedule(schedule.copyWith(syncStatus: 'synced'));
            } else {
              developer.log('Error del servidor al crear horario ${schedule.id}: $e');
            }
          } catch (e) {
            developer.log('Error inesperado al crear horario ${schedule.id}: $e');
          }
        } else if (schedule.syncStatus == 'pending_update') {
          try {
            await ApiService.instance.updateSchedule(schedule.id, schedule.toJson(includeId: false));
            await DatabaseService.instance.updateSchedule(schedule.copyWith(syncStatus: 'synced'));
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            developer.log('Error del servidor al actualizar horario ${schedule.id}: $e');
          } catch (e) {
            developer.log('Error inesperado al actualizar horario ${schedule.id}: $e');
          }
        } else if (schedule.syncStatus == 'pending_delete') {
          try {
            await ApiService.instance.deleteSchedule(schedule.id);
            await DatabaseService.instance.hardDeleteSchedule(schedule.id);
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            if (e.statusCode == 404) {
              await DatabaseService.instance.hardDeleteSchedule(schedule.id);
            } else {
              developer.log('Error del servidor al borrar horario ${schedule.id}: $e');
            }
          } catch (e) {
            developer.log('Error inesperado al borrar horario ${schedule.id}: $e');
          }
        }
      }

      // 1.3 Tareas y exámenes (Tasks)
      final pendingTasks = await DatabaseService.instance.getPendingTasks();
      for (var task in pendingTasks) {
        if (task.localPhotoPath != null && (task.photoUrl == null || task.photoUrl!.isEmpty)) {
          final file = File(task.localPhotoPath!);
          if (await file.exists()) {
            try {
              final uploadedUrl = await ApiService.instance.uploadPhoto(file);
              task = task.copyWith(photoUrl: uploadedUrl, clearLocalPhotoPath: true);
              await DatabaseService.instance.updateTask(task);
            } on ApiException catch (e) {
              if (e.statusCode == 0) {
                return SyncResult(success: false, isOffline: true, error: e.message);
              }
              developer.log('Error subiendo foto de tarea ${task.id}: $e');
            } catch (e) {
              developer.log('Error inesperado subiendo foto de tarea ${task.id}: $e');
            }
          }
        }

        if (task.syncStatus == 'pending_create') {
          try {
            await ApiService.instance.createTask(task);
            await DatabaseService.instance.insertTask(task.copyWith(syncStatus: 'synced'));
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            if (e.statusCode == 409) {
              await DatabaseService.instance.insertTask(task.copyWith(syncStatus: 'synced'));
            } else {
              developer.log('Error del servidor al crear tarea ${task.id}: $e');
            }
          } catch (e) {
            developer.log('Error inesperado al crear tarea ${task.id}: $e');
          }
        } else if (task.syncStatus == 'pending_update') {
          try {
            await ApiService.instance.updateTask(task.id, task.toJson(includeId: false));
            await DatabaseService.instance.updateTask(task.copyWith(syncStatus: 'synced'));
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            developer.log('Error del servidor al actualizar tarea ${task.id}: $e');
          } catch (e) {
            developer.log('Error inesperado al actualizar tarea ${task.id}: $e');
          }
        } else if (task.syncStatus == 'pending_delete') {
          try {
            await ApiService.instance.deleteTask(task.id);
            await DatabaseService.instance.hardDeleteTask(task.id);
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            if (e.statusCode == 404) {
              await DatabaseService.instance.hardDeleteTask(task.id);
            } else {
              developer.log('Error del servidor al borrar tarea ${task.id}: $e');
            }
          } catch (e) {
            developer.log('Error inesperado al borrar tarea ${task.id}: $e');
          }
        }
      }

      // 1.3.1 Tareas ya sincronizadas ('synced') que conservan foto local pendiente de subir
      final tasksWithPendingPhotos = await DatabaseService.instance.getTasksWithPendingPhotoUpload();
      for (var task in tasksWithPendingPhotos) {
        if (task.syncStatus == 'synced' && task.localPhotoPath != null && (task.photoUrl == null || task.photoUrl!.isEmpty)) {
          final file = File(task.localPhotoPath!);
          if (await file.exists()) {
            try {
              final uploadedUrl = await ApiService.instance.uploadPhoto(file);
              await ApiService.instance.updateTask(task.id, {'photoUrl': uploadedUrl});
              final updated = task.copyWith(
                photoUrl: uploadedUrl,
                clearLocalPhotoPath: true,
                syncStatus: 'synced',
              );
              await DatabaseService.instance.updateTask(updated);
            } on ApiException catch (e) {
              if (e.statusCode == 0) {
                return SyncResult(success: false, isOffline: true, error: e.message);
              }
              developer.log('Error subiendo foto pendiente de tarea sincronizada ${task.id}: $e');
            } catch (e) {
              developer.log('Error inesperado subiendo foto de tarea ${task.id}: $e');
            }
          }
        }
      }

      // 1.4 Faltas (Absences)
      final pendingAbsences = await DatabaseService.instance.getPendingAbsences();
      for (final absence in pendingAbsences) {
        if (absence.syncStatus == 'pending_create') {
          try {
            await ApiService.instance.createAbsence(absence);
            await DatabaseService.instance.insertAbsence(absence.copyWith(syncStatus: 'synced'));
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            if (e.statusCode == 409) {
              await DatabaseService.instance.insertAbsence(absence.copyWith(syncStatus: 'synced'));
            } else {
              developer.log('Error del servidor al crear falta ${absence.id}: $e');
            }
          } catch (e) {
            developer.log('Error inesperado al crear falta ${absence.id}: $e');
          }
        } else if (absence.syncStatus == 'pending_update') {
          try {
            await ApiService.instance.updateAbsence(absence.id, absence.toJson(includeId: false));
            await DatabaseService.instance.updateAbsence(absence.copyWith(syncStatus: 'synced'));
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            developer.log('Error del servidor al actualizar falta ${absence.id}: $e');
          } catch (e) {
            developer.log('Error inesperado al actualizar falta ${absence.id}: $e');
          }
        } else if (absence.syncStatus == 'pending_delete') {
          try {
            await ApiService.instance.deleteAbsence(absence.id);
            await DatabaseService.instance.hardDeleteAbsence(absence.id);
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            if (e.statusCode == 404) {
              await DatabaseService.instance.hardDeleteAbsence(absence.id);
            } else {
              developer.log('Error del servidor al borrar falta ${absence.id}: $e');
            }
          } catch (e) {
            developer.log('Error inesperado al borrar falta ${absence.id}: $e');
          }
        }
      }

      // 1.5 Calificaciones (Grades)
      final pendingGrades = await DatabaseService.instance.getPendingGrades();
      for (final grade in pendingGrades) {
        if (grade.syncStatus == 'pending_create') {
          try {
            await ApiService.instance.createGrade(grade);
            await DatabaseService.instance.insertGrade(grade.copyWith(syncStatus: 'synced'));
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            if (e.statusCode == 409) {
              await DatabaseService.instance.insertGrade(grade.copyWith(syncStatus: 'synced'));
            } else {
              developer.log('Error del servidor al crear calificación ${grade.id}: $e');
            }
          } catch (e) {
            developer.log('Error inesperado al crear calificación ${grade.id}: $e');
          }
        } else if (grade.syncStatus == 'pending_update') {
          try {
            await ApiService.instance.updateGrade(grade.id, grade.toJson(includeId: false));
            await DatabaseService.instance.updateGrade(grade.copyWith(syncStatus: 'synced'));
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            developer.log('Error del servidor al actualizar calificación ${grade.id}: $e');
          } catch (e) {
            developer.log('Error inesperado al actualizar calificación ${grade.id}: $e');
          }
        } else if (grade.syncStatus == 'pending_delete') {
          try {
            await ApiService.instance.deleteGrade(grade.id);
            await DatabaseService.instance.hardDeleteGrade(grade.id);
          } on ApiException catch (e) {
            if (e.statusCode == 0) {
              return SyncResult(success: false, isOffline: true, error: e.message);
            }
            if (e.statusCode == 404) {
              await DatabaseService.instance.hardDeleteGrade(grade.id);
            } else {
              developer.log('Error del servidor al borrar calificación ${grade.id}: $e');
            }
          } catch (e) {
            developer.log('Error inesperado al borrar calificación ${grade.id}: $e');
          }
        }
      }

      // ========================================================
      // 2. TRAER CAMBIOS DESDE EL BACKEND
      // ========================================================
      final lastSyncTime = await StorageService.instance.getLastSyncTime();
      final syncData = await ApiService.instance.sync(since: lastSyncTime);

      final newServerTime = syncData['serverTime'] as String?;

      // 2.1 Procesar materias
      final subjectsList = syncData['subjects'] as List<dynamic>? ?? [];
      for (final item in subjectsList) {
        final subject = Subject.fromJson(item as Map<String, dynamic>);
        await DatabaseService.instance.upsertSubjectFromSync(subject);
      }

      // 2.2 Procesar horario (schedules)
      final schedulesList = syncData['schedules'] as List<dynamic>? ?? [];
      for (final item in schedulesList) {
        final schedule = Schedule.fromJson(item as Map<String, dynamic>);
        await DatabaseService.instance.upsertScheduleFromSync(schedule);
      }

      // 2.3 Procesar tareas (tasks)
      final tasksList = syncData['tasks'] as List<dynamic>? ?? [];
      for (final item in tasksList) {
        final task = TaskItem.fromJson(item as Map<String, dynamic>);
        await DatabaseService.instance.upsertTaskFromSync(task);
      }

      // 2.4 Procesar faltas (absences)
      final absencesList = syncData['absences'] as List<dynamic>? ?? [];
      for (final item in absencesList) {
        final absence = Absence.fromJson(item as Map<String, dynamic>);
        await DatabaseService.instance.upsertAbsenceFromSync(absence);
      }

      // 2.5 Procesar calificaciones (grades)
      final gradesList = syncData['grades'] as List<dynamic>? ?? [];
      for (final item in gradesList) {
        final grade = Grade.fromJson(item as Map<String, dynamic>);
        await DatabaseService.instance.upsertGradeFromSync(grade);
      }

      if (newServerTime != null) {
        await StorageService.instance.saveLastSyncTime(newServerTime);
      }

      onSyncCompleted?.call();
      return SyncResult(success: true);
    } on ApiException catch (e) {
      return SyncResult(
        success: false,
        isOffline: e.statusCode == 0,
        error: e.message,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        error: e.toString(),
      );
    }
  }
}
