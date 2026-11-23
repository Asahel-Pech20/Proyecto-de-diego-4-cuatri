import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/subject_provider.dart';
import 'schedule_form_dialog.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<Map<String, dynamic>> _days = [
    {'day': 1, 'name': 'Lun', 'fullName': 'Lunes'},
    {'day': 2, 'name': 'Mar', 'fullName': 'Martes'},
    {'day': 3, 'name': 'Mié', 'fullName': 'Miércoles'},
    {'day': 4, 'name': 'Jue', 'fullName': 'Jueves'},
    {'day': 5, 'name': 'Vie', 'fullName': 'Viernes'},
    {'day': 6, 'name': 'Sáb', 'fullName': 'Sábado'},
  ];

  @override
  void initState() {
    super.initState();
    // Determinar día inicial según hoy (si es domingo, sugerir lunes)
    final todayWeekday = DateTime.now().weekday;
    final initialIndex = (todayWeekday >= 1 && todayWeekday <= 6) ? todayWeekday - 1 : 0;
    _tabController = TabController(length: 6, vsync: this, initialIndex: initialIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().loadSchedules();
      context.read<SubjectProvider>().loadSubjects(triggerSync: false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _confirmDelete(BuildContext context, Schedule schedule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar clase?'),
        content: Text('Se eliminará la clase de las ${schedule.startTime} - ${schedule.endTime} de tu horario.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final provider = context.read<ScheduleProvider>();
    final ok = await provider.deleteSchedule(schedule.id);

    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clase eliminada del horario'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = context.watch<ScheduleProvider>();
    final subjectProvider = context.watch<SubjectProvider>();

    final subjectMap = {for (var s in subjectProvider.subjects) s.id: s};

    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        title: const Text('Horario Semanal', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: AppConstants.accentColor,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          tabs: _days.map((d) => Tab(text: d['name'] as String)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final currentDay = _days[_tabController.index]['day'] as int;
          ScheduleFormDialog.show(context, initialDay: currentDay);
        },
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar Clase'),
      ),
      body: scheduleProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _days.map((d) {
                final dayVal = d['day'] as int;
                final classes = scheduleProvider.getSchedulesForDay(dayVal);

                if (classes.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Sin clases el ${d['fullName']}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textColor),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No tienes clases programadas para este día.',
                            style: TextStyle(color: AppConstants.textMuted),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => ScheduleFormDialog.show(context, initialDay: dayVal),
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar clase a este día'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => scheduleProvider.loadSchedules(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: classes.length,
                    itemBuilder: (ctx, index) {
                      final item = classes[index];
                      final subject = subjectMap[item.subjectId];
                      final subjectName = subject?.name ?? 'Materia';
                      final color = _parseHex(subject?.color);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // Franja de color y horario
                              Container(
                                width: 5,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subjectName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppConstants.textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${item.startTime} - ${item.endTime}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        if (item.room != null && item.room!.isNotEmpty) ...[
                                          const SizedBox(width: 12),
                                          Icon(Icons.meeting_room_outlined, size: 14, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.room!,
                                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (item.syncStatus != 'synced') ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.cloud_upload_outlined, size: 12, color: Colors.amber.shade900),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Pendiente sync',
                                            style: TextStyle(fontSize: 10, color: Colors.amber.shade900),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Acciones
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: AppConstants.textMuted),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    ScheduleFormDialog.show(context, schedule: item, initialDay: dayVal);
                                  } else if (action == 'delete') {
                                    _confirmDelete(context, item);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Editar'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
    );
  }
}
