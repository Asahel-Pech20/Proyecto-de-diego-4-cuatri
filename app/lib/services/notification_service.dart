import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/task_item.dart';

class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  Future<void> init() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (e) {
      debugPrint('Error configurando zona horaria: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(settings: initSettings);

    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Calcula el ID entero estable para la notificación de una tarea y su índice de recordatorio
  static int getNotificationId(String taskId, int reminderIndex) {
    return (taskId.hashCode.abs() * 31 + reminderIndex) & 0x7FFFFFFF;
  }

  /// Calcula las fechas de recordatorio válidas (que aún no han pasado respecto a now)
  static List<DateTime> calculateReminderTimes(DateTime dueAt, List<int> reminders, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final List<DateTime> validTimes = [];

    for (final minutes in reminders) {
      final reminderTime = dueAt.subtract(Duration(minutes: minutes));
      if (reminderTime.isAfter(current)) {
        validTimes.add(reminderTime);
      }
    }
    return validTimes;
  }

  static String _formatReminderTimeText(int minutes) {
    if (minutes == 10) return 'en 10 minutos';
    if (minutes == 30) return 'en 30 minutos';
    if (minutes == 60) return 'en 1 hora';
    if (minutes == 120) return 'en 2 horas';
    if (minutes == 1440) return 'mañana';
    if (minutes == 2880) return 'en 2 días';
    if (minutes < 60) return 'en $minutes minutos';
    if (minutes < 1440) return 'en ${minutes ~/ 60} horas';
    return 'en ${minutes ~/ 1440} días';
  }

  Future<void> scheduleTaskReminders(TaskItem task, String subjectName) async {
    // 1. Cancelar recordatorios previos de esta tarea
    await cancelTaskReminders(task.id);

    // Si ya está completada o borrada, no programar recordatorios
    if (task.done || task.deletedAt != null) return;

    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');

    for (var i = 0; i < task.reminders.length; i++) {
      final minutes = task.reminders[i];
      final reminderTime = task.dueAt.subtract(Duration(minutes: minutes));

      // Solo si esa hora todavía no ha pasado
      if (reminderTime.isAfter(now)) {
        final notifId = getNotificationId(task.id, i);
        final timeText = _formatReminderTimeText(minutes);
        final formattedHour = timeFormat.format(task.dueAt.toLocal());

        String title;
        String body;

        if (task.isExam) {
          title = 'Examen de $subjectName';
          body = 'Examen de $subjectName $timeText a las $formattedHour.';
        } else {
          title = 'Recordatorio de entrega';
          body = 'Entrega: ${task.title} ($subjectName) $timeText.';
        }

        const androidDetails = AndroidNotificationDetails(
          'misemestre_reminders',
          'Recordatorios Académicos',
          channelDescription: 'Avisos y notificaciones de entregas y exámenes',
          importance: Importance.high,
          priority: Priority.high,
        );

        const details = NotificationDetails(android: androidDetails);

        try {
          await _notificationsPlugin.zonedSchedule(
            id: notifId,
            scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            title: title,
            body: body,
          );
        } catch (e) {
          debugPrint('Error programando notificación $notifId: $e');
        }
      }
    }
  }

  final List<String> lastCancelledTaskIds = [];

  Future<void> cancelTaskReminders(String taskId) async {
    lastCancelledTaskIds.add(taskId);
    try {
      // Hasta 10 recordatorios posibles por tarea
      for (var i = 0; i < 10; i++) {
        final notifId = getNotificationId(taskId, i);
        await _notificationsPlugin.cancel(id: notifId);
      }
    } catch (e) {
      debugPrint('Error cancelando recordatorios de tarea $taskId: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error cancelando todas las notificaciones: $e');
    }
  }

  Future<void> rescheduleAllReminders(
    List<TaskItem> tasks,
    Map<String, String> subjectNames,
  ) async {
    // Cancelar primero todas las notificaciones para evitar recordatorios huérfanos
    await _notificationsPlugin.cancelAll();

    for (final task in tasks) {
      if (!task.done && task.deletedAt == null) {
        final subjectName = subjectNames[task.subjectId] ?? 'Materia';
        await scheduleTaskReminders(task, subjectName);
      }
    }
  }

  final List<Map<String, dynamic>> lastImmediateNotifications = [];

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    lastImmediateNotifications.add({'id': id, 'title': title, 'body': body});
    try {
      const androidDetails = AndroidNotificationDetails(
        'misemestre_alerts',
        'Alertas de Asistencia',
        channelDescription: 'Avisos de límite de faltas de materias',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Error mostrando notificación inmediata: $e');
    }
  }
}
