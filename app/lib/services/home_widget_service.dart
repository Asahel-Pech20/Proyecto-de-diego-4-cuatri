import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/schedule.dart';
import 'database_service.dart';

class HomeWidgetService {
  static const String appWidgetProviderName = 'HomeScreenWidgetProvider';

  static Future<void> updateWidget() async {
    try {
      final db = DatabaseService.instance;
      final schedules = await db.getSchedules();
      final subjects = await db.getSubjects();
      final tasks = await db.getTasks();

      final subjectMap = {for (var s in subjects) s.id: s.name};
      final now = DateTime.now();

      // Encontrar la siguiente clase de hoy
      final todayDayOfWeek = now.weekday; // 1 = Lunes, 7 = Domingo
      final todaySchedules = schedules
          .where((s) => s.dayOfWeek == todayDayOfWeek && s.deletedAt == null)
          .toList();
      todaySchedules.sort((a, b) => a.startTime.compareTo(b.startTime));

      Schedule? nextSchedule;
      for (final s in todaySchedules) {
        final parts = s.endTime.split(':');
        final endHour = int.tryParse(parts[0]) ?? 0;
        final endMinute = int.tryParse(parts[1]) ?? 0;
        final endDateTime = DateTime(now.year, now.month, now.day, endHour, endMinute);
        if (endDateTime.isAfter(now)) {
          nextSchedule = s;
          break;
        }
      }

      String nextClassSubject = '';
      String nextClassTime = '';
      String nextClassRoom = '';

      if (nextSchedule != null) {
        nextClassSubject = subjectMap[nextSchedule.subjectId] ?? 'Materia';
        nextClassTime = '${nextSchedule.startTime} - ${nextSchedule.endTime}';
        nextClassRoom = nextSchedule.room ?? '';
      }

      // Tareas de hoy (máximo 3)
      final todayTasks = tasks.where((t) {
        if (t.done || t.deletedAt != null) return false;
        final d = t.dueAt.toLocal();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();

      todayTasks.sort((a, b) => a.dueAt.compareTo(b.dueAt));

      final topTasks = todayTasks.take(3).toList();
      String tasksText;
      if (topTasks.isEmpty) {
        tasksText = 'Sin tareas pendientes para hoy';
      } else {
        tasksText = topTasks.map((t) {
          final sName = subjectMap[t.subjectId] ?? '';
          final prefix = t.isExam ? '📝 Examen: ' : '• ';
          return '$prefix${t.title}${sName.isNotEmpty ? " ($sName)" : ""}';
        }).join('\n');
      }

      await HomeWidget.saveWidgetData<String>('next_class_subject', nextClassSubject);
      await HomeWidget.saveWidgetData<String>('next_class_time', nextClassTime);
      await HomeWidget.saveWidgetData<String>('next_class_room', nextClassRoom);
      await HomeWidget.saveWidgetData<String>('today_tasks_text', tasksText);

      await HomeWidget.updateWidget(
        name: appWidgetProviderName,
        androidName: appWidgetProviderName,
      );
    } catch (e) {
      debugPrint('Error actualizando HomeWidget: $e');
    }
  }
}
