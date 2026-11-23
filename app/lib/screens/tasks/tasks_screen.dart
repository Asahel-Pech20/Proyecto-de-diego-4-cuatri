import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/constants.dart';
import '../../models/task_item.dart';
import '../../models/subject.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subject_provider.dart';
import '../../providers/task_provider.dart';
import 'task_form_dialog.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _filter = 'all'; // 'all', 'tasks', 'exams', 'completed'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
      context.read<SubjectProvider>().loadSubjects(triggerSync: false);
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

  void _showPhotoDialog(BuildContext context, TaskItem task) {
    final token = context.read<AuthProvider>().token;
    final baseUrl = ApiConfig.instance.baseUrl;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(task.title, style: const TextStyle(fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            if (task.localPhotoPath != null && File(task.localPhotoPath!).existsSync())
              Image.file(File(task.localPhotoPath!), fit: BoxFit.contain)
            else if (task.photoUrl != null)
              Image.network(
                '$baseUrl${task.photoUrl}',
                headers: token != null ? {'Authorization': 'Bearer $token'} : null,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No se pudo cargar la imagen')),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Sin imagen disponible')),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, TaskItem task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar actividad?'),
        content: Text('Se eliminará "${task.title}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final provider = context.read<TaskProvider>();
    final ok = await provider.deleteTask(task.id);

    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actividad eliminada'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final subjectProvider = context.watch<SubjectProvider>();
    final subjectMap = {for (var s in subjectProvider.subjects) s.id: s};

    final allTasks = taskProvider.tasks;
    final filteredTasks = allTasks.where((t) {
      if (_filter == 'tasks') return !t.isExam && !t.done;
      if (_filter == 'exams') return t.isExam && !t.done;
      if (_filter == 'completed') return t.done;
      return true;
    }).toList();

    final grouped = TaskProvider.groupTasks(filteredTasks);

    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        title: const Text('Tareas y Exámenes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TaskFormDialog.show(context),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Nueva Actividad'),
      ),
      body: Column(
        children: [
          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Todas', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Solo Tareas', 'tasks'),
                const SizedBox(width: 8),
                _buildFilterChip('Exámenes', 'exams'),
                const SizedBox(width: 8),
                _buildFilterChip('Completadas', 'completed'),
              ],
            ),
          ),

          // Lista agrupada
          Expanded(
            child: taskProvider.isLoading && allTasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : grouped.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.task_alt_rounded, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay actividades pendientes',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textColor),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '¡Estás al día con tus entregas y exámenes!',
                                style: TextStyle(color: AppConstants.textMuted),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => TaskFormDialog.show(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar tarea o examen'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => taskProvider.loadTasks(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          children: [
                            if (grouped.overdue.isNotEmpty)
                              _buildSection('Vencidas', grouped.overdue, Colors.red.shade700, Icons.warning_amber_rounded, subjectMap),
                            if (grouped.today.isNotEmpty)
                              _buildSection('Para Hoy', grouped.today, Colors.deepOrange.shade700, Icons.today_rounded, subjectMap),
                            if (grouped.tomorrow.isNotEmpty)
                              _buildSection('Para Mañana', grouped.tomorrow, Colors.amber.shade800, Icons.event_rounded, subjectMap),
                            if (grouped.thisWeek.isNotEmpty)
                              _buildSection('Esta semana', grouped.thisWeek, Colors.blue.shade700, Icons.date_range_rounded, subjectMap),
                            if (grouped.later.isNotEmpty)
                              _buildSection('Después', grouped.later, Colors.purple.shade700, Icons.next_week_outlined, subjectMap),
                            if (grouped.completed.isNotEmpty)
                              _buildSection('Completadas', grouped.completed, Colors.green.shade700, Icons.check_circle_outline_rounded, subjectMap),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (sel) {
        if (sel) setState(() => _filter = value);
      },
      selectedColor: AppConstants.primaryColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppConstants.primaryColor : AppConstants.textColor,
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<TaskItem> sectionTasks,
    Color color,
    IconData icon,
    Map<String, Subject> subjectMap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                '$title (${sectionTasks.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        ...sectionTasks.map((task) => _buildTaskCard(task, subjectMap[task.subjectId])),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTaskCard(TaskItem task, Subject? subject) {
    final color = _parseHex(subject?.color);
    final subjectName = subject?.name ?? 'Materia';
    final taskProvider = context.read<TaskProvider>();
    final dateFormat = DateFormat('EEE, d MMM • HH:mm', 'es');

    final hasPhoto = (task.localPhotoPath != null && File(task.localPhotoPath!).existsSync()) || task.photoUrl != null;

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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox para marcar hecha con 1 toque
              Transform.scale(
                scale: 1.1,
                child: Checkbox(
                  value: task.done,
                  activeColor: AppConstants.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (_) {
                    taskProvider.toggleDone(task, subjectName: subjectName);
                  },
                ),
              ),
              const SizedBox(width: 4),

              // Indicador de color de la materia
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (task.isExam) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Text(
                              'EXAMEN',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              decoration: task.done ? TextDecoration.lineThrough : null,
                              color: task.done ? Colors.grey : AppConstants.textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subjectName,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• ${dateFormat.format(task.dueAt.toLocal())}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

              // Icono de foto si existe
              if (hasPhoto)
                IconButton(
                  icon: const Icon(Icons.image_outlined, color: AppConstants.primaryColor, size: 20),
                  tooltip: 'Ver foto adjunta',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  onPressed: () => _showPhotoDialog(context, task),
                ),

              // Menú eliminar
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppConstants.textMuted),
                onSelected: (action) {
                  if (action == 'edit') {
                    TaskFormDialog.show(context, task: task);
                  } else if (action == 'delete') {
                    _confirmDelete(context, task);
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
      ),
    );
  }
}
