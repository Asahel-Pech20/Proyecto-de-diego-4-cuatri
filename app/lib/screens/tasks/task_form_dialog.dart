import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/schedule.dart';
import '../../models/task_item.dart';
import '../../models/subject.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/subject_provider.dart';
import '../../providers/task_provider.dart';

class TaskFormDialog extends StatefulWidget {
  final TaskItem? task;

  const TaskFormDialog({super.key, this.task});

  static Future<void> show(BuildContext context, {TaskItem? task}) {
    return showDialog(
      context: context,
      builder: (ctx) => TaskFormDialog(task: task),
    );
  }

  /// Encuentra la fecha y hora de la próxima clase de una materia específica
  static DateTime? findNextClassStartTime(
    List<Schedule> allSchedules,
    String subjectId, {
    DateTime? from,
  }) {
    final now = from ?? DateTime.now();
    final subjectSchedules = allSchedules
        .where((s) => s.subjectId == subjectId && s.deletedAt == null)
        .toList();

    if (subjectSchedules.isEmpty) return null;

    DateTime? earliest;

    for (int dayOffset = 0; dayOffset <= 14; dayOffset++) {
      final date = now.add(Duration(days: dayOffset));
      final dayOfWeek = date.weekday; // 1 = Lunes ... 7 = Domingo

      final dayClasses = subjectSchedules.where((s) => s.dayOfWeek == dayOfWeek);
      for (final cls in dayClasses) {
        final parts = cls.startTime.split(':');
        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = int.tryParse(parts[1]) ?? 0;
        final classDateTime = DateTime(date.year, date.month, date.day, hour, minute);

        if (classDateTime.isAfter(now)) {
          if (earliest == null || classDateTime.isBefore(earliest)) {
            earliest = classDateTime;
          }
        }
      }

      if (earliest != null && dayOffset > 0) {
        break;
      }
    }

    return earliest;
  }

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubjectId;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _dueAt;
  String _kind = 'task'; // "task" o "exam"
  File? _selectedPhotoFile;
  String? _currentPhotoUrl;
  List<int> _selectedReminders = [1440, 120];
  bool _isSaving = false;

  bool get isEditing => widget.task != null;

  static const List<Map<String, dynamic>> _reminderOptions = [
    {'minutes': 10, 'label': '10 min'},
    {'minutes': 30, 'label': '30 min'},
    {'minutes': 60, 'label': '1 h'},
    {'minutes': 120, 'label': '2 h'},
    {'minutes': 1440, 'label': '1 día'},
    {'minutes': 2880, 'label': '2 días'},
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.task;

    if (t != null) {
      _selectedSubjectId = t.subjectId;
      _titleController = TextEditingController(text: t.title);
      _descriptionController = TextEditingController(text: t.description ?? '');
      _dueAt = t.dueAt.toLocal();
      _kind = t.kind;
      _currentPhotoUrl = t.photoUrl;
      if (t.localPhotoPath != null) {
        final f = File(t.localPhotoPath!);
        if (f.existsSync()) _selectedPhotoFile = f;
      }
      _selectedReminders = List<int>.from(t.reminders);
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();

      // Detección automática para captura rápida (máximo 3 toques):
      // Si hay una clase en curso o la siguiente clase de hoy, preselecciona esa materia por defecto,
      // y pon como fecha/hora de entrega por defecto el inicio de la siguiente clase de esa materia.
      final scheduleProvider = context.read<ScheduleProvider>();
      final currentAndNext = scheduleProvider.getCurrentAndNextClass();

      final relevantClass = currentAndNext.current ?? currentAndNext.next;
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      if (relevantClass != null) {
        _selectedSubjectId = relevantClass.subjectId;
        final nextClassTime = TaskFormDialog.findNextClassStartTime(
          scheduleProvider.schedules,
          relevantClass.subjectId,
        );

        if (nextClassTime != null) {
          _dueAt = nextClassTime;
        } else {
          final parts = relevantClass.startTime.split(':');
          final hour = int.tryParse(parts[0]) ?? 8;
          final minute = int.tryParse(parts[1]) ?? 0;
          _dueAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
        }
      } else {
        // Mañana a las 23:59 por defecto
        _dueAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _dueAt.hour, minute: _dueAt.minute),
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _dueAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 70, // Compresión 70%
      maxWidth: 1600, // Máx ancho 1600px
    );
    if (picked != null) {
      setState(() {
        _selectedPhotoFile = File(picked.path);
        _currentPhotoUrl = null;
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppConstants.primaryColor),
              title: const Text('Tomar foto con la cámara'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppConstants.primaryColor),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una materia')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final subjects = context.read<SubjectProvider>().subjects;
    final subject = subjects.firstWhere(
      (s) => s.id == _selectedSubjectId,
      orElse: () => Subject(id: _selectedSubjectId!, name: 'Materia'),
    );

    final taskProvider = context.read<TaskProvider>();
    bool ok;

    if (isEditing) {
      ok = await taskProvider.updateTask(
        id: widget.task!.id,
        subjectId: _selectedSubjectId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        dueAt: _dueAt,
        kind: _kind,
        photoUrl: _currentPhotoUrl,
        localPhotoPath: _selectedPhotoFile?.path,
        reminders: _selectedReminders,
        done: widget.task!.done,
        subjectName: subject.name,
      );
    } else {
      ok = await taskProvider.createTask(
        subjectId: _selectedSubjectId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        dueAt: _dueAt,
        kind: _kind,
        photoFile: _selectedPhotoFile,
        reminders: _selectedReminders,
        subjectName: subject.name,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Tarea actualizada' : 'Tarea creada con éxito'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskProvider.errorMessage ?? 'Error al guardar la tarea'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = context.watch<SubjectProvider>().subjects;
    if (_selectedSubjectId == null && subjects.isNotEmpty) {
      _selectedSubjectId = subjects.first.id;
    }

    final formattedDate = DateFormat('EEE, d MMM y • HH:mm', 'es').format(_dueAt);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _kind == 'exam' ? Icons.assignment_late_outlined : Icons.assignment_outlined,
            color: AppConstants.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(isEditing ? 'Editar Actividad' : 'Nueva Actividad'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector Tipo: Tarea o Examen
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_note_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Tarea'),
                          ],
                        ),
                        selected: _kind == 'task',
                        onSelected: (sel) {
                          if (sel) setState(() => _kind = 'task');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_late_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Examen'),
                          ],
                        ),
                        selected: _kind == 'exam',
                        selectedColor: Colors.red.shade100,
                        onSelected: (sel) {
                          if (sel) setState(() => _kind = 'exam');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Materia
                const Text('Materia *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSubjectId,
                  items: subjects.map((Subject s) {
                    return DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedSubjectId = val),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (v) => v == null ? 'Selecciona una materia' : null,
                ),
                const SizedBox(height: 14),

                // Título
                const Text('Título *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: _kind == 'exam' ? 'Ej. Primer Examen Parcial' : 'Ej. Ejercicios Tema 2',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa el título';
                    if (v.trim().length > 200) return 'Máximo 200 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Fecha y Hora de Entrega
                const Text('Fecha y hora de entrega *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppConstants.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Descripción opcional
                const Text('Descripción / Instrucciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Puntos clave, páginas del libro...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 14),

                // Foto adjunta
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Foto adjunta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    TextButton.icon(
                      onPressed: _showImageSourceDialog,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: Text(_selectedPhotoFile != null || _currentPhotoUrl != null ? 'Cambiar' : 'Adjuntar'),
                    ),
                  ],
                ),
                if (_selectedPhotoFile != null) ...[
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedPhotoFile!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 14,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, size: 16, color: Colors.white),
                            onPressed: () => setState(() => _selectedPhotoFile = null),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // Recordatorios
                const Text('Recordatorios anticipados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _reminderOptions.map((opt) {
                    final mins = opt['minutes'] as int;
                    final isSelected = _selectedReminders.contains(mins);
                    return FilterChip(
                      label: Text(opt['label'] as String, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            if (_selectedReminders.length < 10) {
                              _selectedReminders.add(mins);
                              _selectedReminders.sort((a, b) => b.compareTo(a));
                            }
                          } else {
                            _selectedReminders.remove(mins);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Guardar' : 'Crear Tarea'),
        ),
      ],
    );
  }
}
