import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/schedule.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/subject_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/sync_service.dart';
import '../settings/settings_screen.dart';
import '../tasks/task_form_dialog.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      context.read<SubjectProvider>().loadSubjects(triggerSync: false),
      context.read<ScheduleProvider>().loadSchedules(),
      context.read<TaskProvider>().loadTasks(),
    ]);
    // Sincronizar en segundo plano
    SyncService.instance.synchronize().then((_) {
      if (mounted) {
        context.read<SubjectProvider>().loadSubjects(triggerSync: false);
        context.read<ScheduleProvider>().loadSchedules();
        context.read<TaskProvider>().loadTasks();
      }
    });
  }

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return AppConstants.primaryColor;
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppConstants.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final subjectProvider = context.watch<SubjectProvider>();

    final subjectMap = {for (var s in subjectProvider.subjects) s.id: s};

    // Calcular clase actual y clase que sigue
    final currentAndNext = scheduleProvider.getCurrentAndNextClass();
    final groupedTasks = taskProvider.groupedTasks;

    final todayTasks = groupedTasks.today;
    final tomorrowTasks = groupedTasks.tomorrow;

    final userName = auth.currentUser?.name.split(' ').first ?? 'Estudiante';

    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¡Hola, $userName! 👋', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Text(
              'MiSemestre UTM',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sincronizar ahora',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sincronizando datos...'), duration: Duration(seconds: 1)),
              );
              await _refreshAllData();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TaskFormDialog.show(context),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Nueva Tarea'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // SECCIÓN "¿QUÉ CLASE SIGUE? / AHORA"
              // ==========================================
              _buildClassBanner(currentAndNext, subjectMap),
              const SizedBox(height: 18),

              // ==========================================
              // PENDIENTES DE HOY
              // ==========================================
              _buildSectionHeader('Pendientes de hoy', todayTasks.length, Icons.today_rounded, Colors.deepOrange),
              const SizedBox(height: 8),
              if (todayTasks.isEmpty)
                _buildEmptyCard('¡Todo listo por hoy!', 'No tienes entregas ni exámenes pendientes para hoy.')
              else
                ...todayTasks.map((t) => _buildMiniTaskCard(t, subjectMap[t.subjectId])),

              const SizedBox(height: 18),

              // ==========================================
              // PENDIENTES DE MAÑANA
              // ==========================================
              _buildSectionHeader('Para mañana', tomorrowTasks.length, Icons.event_rounded, Colors.amber.shade800),
              const SizedBox(height: 8),
              if (tomorrowTasks.isEmpty)
                _buildEmptyCard('Día despejado mañana', 'No tienes pendientes programados para mañana.')
              else
                ...tomorrowTasks.map((t) => _buildMiniTaskCard(t, subjectMap[t.subjectId])),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassBanner(CurrentAndNextClass currentAndNext, Map<String, Subject> subjectMap) {
    final current = currentAndNext.current;
    final next = currentAndNext.next;

    if (current == null && next == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.celebration_rounded, color: Colors.green.shade700, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No hay más clases por hoy 🎉',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.textColor),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Aprovecha para repasar o descansar.',
                      style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clase en curso
            if (current != null) ...[
              _buildClassItem(
                label: 'AHORA',
                labelColor: Colors.green.shade800,
                labelBg: Colors.green.shade100,
                schedule: current,
                subject: subjectMap[current.subjectId],
              ),
              if (next != null) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
            ],

            // Próxima clase
            if (next != null) ...[
              _buildClassItem(
                label: 'SIGUE',
                labelColor: Colors.blue.shade800,
                labelBg: Colors.blue.shade100,
                schedule: next,
                subject: subjectMap[next.subjectId],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClassItem({
    required String label,
    required Color labelColor,
    required Color labelBg,
    required Schedule schedule,
    required Subject? subject,
  }) {
    final color = _parseHex(subject?.color);
    final subjectName = subject?.name ?? 'Materia';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: labelColor),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 4,
          height: 38,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subjectName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppConstants.textColor),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${schedule.startTime} - ${schedule.endTime}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                  ),
                  if (schedule.room != null && schedule.room!.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Icon(Icons.meeting_room_outlined, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        schedule.room!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textColor),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String title, String subtitle) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppConstants.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTaskCard(TaskItem task, Subject? subject) {
    final color = _parseHex(subject?.color);
    final subjectName = subject?.name ?? 'Materia';
    final taskProvider = context.read<TaskProvider>();
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => TaskFormDialog.show(context, task: task),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: task.done,
                activeColor: AppConstants.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (_) {
                  taskProvider.toggleDone(task, subjectName: subjectName);
                },
              ),
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: task.done ? TextDecoration.lineThrough : null,
                        color: task.done ? Colors.grey : AppConstants.textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (task.isExam) ...[
                          Text(
                            'EXAMEN • ',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                          ),
                        ],
                        Text(
                          subjectName,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• ${timeFormat.format(task.dueAt.toLocal())}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    if (task.syncStatus != 'synced') ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 12, color: Colors.brown.shade800),
                            const SizedBox(width: 4),
                            Text(
                              'Pendiente sync',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.brown.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
