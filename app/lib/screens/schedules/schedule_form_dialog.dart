import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/schedule.dart';
import '../../models/subject.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/subject_provider.dart';

class ScheduleFormDialog extends StatefulWidget {
  final Schedule? schedule;
  final int initialDay;

  const ScheduleFormDialog({super.key, this.schedule, this.initialDay = 1});

  static Future<void> show(BuildContext context, {Schedule? schedule, int initialDay = 1}) {
    return showDialog(
      context: context,
      builder: (ctx) => ScheduleFormDialog(schedule: schedule, initialDay: initialDay),
    );
  }

  @override
  State<ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<ScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubjectId;
  late int _selectedDay;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late TextEditingController _roomController;
  final Set<int> _repeatDays = {};
  bool _isSaving = false;

  bool get isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _selectedSubjectId = s?.subjectId;
    _selectedDay = s?.dayOfWeek ?? widget.initialDay;

    if (s != null) {
      final startParts = s.startTime.split(':');
      _startTime = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
      final endParts = s.endTime.split(':');
      _endTime = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
    } else {
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
    }

    _roomController = TextEditingController(text: s?.room ?? '');
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Si la hora de fin es menor o igual, sugerir hora posterior
        if (_toMinutes(_endTime) <= _toMinutes(_startTime)) {
          _endTime = TimeOfDay(hour: (_startTime.hour + 2) % 24, minute: _startTime.minute);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_toMinutes(_endTime) <= _toMinutes(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La hora de fin debe ser posterior a la de inicio.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<ScheduleProvider>();
    final startStr = _formatTime(_startTime);
    final endStr = _formatTime(_endTime);
    final room = _roomController.text.trim().isEmpty ? null : _roomController.text.trim();

    bool ok;
    if (isEditing) {
      ok = await provider.updateSchedule(
        id: widget.schedule!.id,
        subjectId: _selectedSubjectId!,
        dayOfWeek: _selectedDay,
        startTime: startStr,
        endTime: endStr,
        room: room,
      );
    } else {
      ok = await provider.createSchedule(
        subjectId: _selectedSubjectId!,
        dayOfWeek: _selectedDay,
        startTime: startStr,
        endTime: endStr,
        room: room,
      );

      // Replicar en otros días seleccionados
      if (ok) {
        for (final extraDay in _repeatDays) {
          if (extraDay != _selectedDay) {
            await provider.createSchedule(
              subjectId: _selectedSubjectId!,
              dayOfWeek: extraDay,
              startTime: startStr,
              endTime: endStr,
              room: room,
            );
          }
        }
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.of(context).pop();
      final msg = isEditing
          ? 'Clase actualizada'
          : (_repeatDays.isNotEmpty ? 'Clases agregadas al horario' : 'Clase agregada al horario');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al guardar la clase'),
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

    const days = [
      {'val': 1, 'name': 'Lunes'},
      {'val': 2, 'name': 'Martes'},
      {'val': 3, 'name': 'Miércoles'},
      {'val': 4, 'name': 'Jueves'},
      {'val': 5, 'name': 'Viernes'},
      {'val': 6, 'name': 'Sábado'},
    ];

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: AppConstants.primaryColor),
          const SizedBox(width: 8),
          Text(isEditing ? 'Editar Clase' : 'Agregar Clase'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selección de materia
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
              const SizedBox(height: 16),

              // Día de la semana
              const Text('Día *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: _selectedDay,
                items: days.map((d) {
                  return DropdownMenuItem<int>(
                    value: d['val'] as int,
                    child: Text(d['name'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedDay = val;
                      _repeatDays.remove(val);
                    });
                  }
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              if (!isEditing) ...[
                const SizedBox(height: 14),
                const Text(
                  'Repetir en otros días',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    for (final d in const [
                      {'val': 1, 'label': 'L', 'name': 'Lun'},
                      {'val': 2, 'label': 'M', 'name': 'Mar'},
                      {'val': 3, 'label': 'M', 'name': 'Mié'},
                      {'val': 4, 'label': 'J', 'name': 'Jue'},
                      {'val': 5, 'label': 'V', 'name': 'Vie'},
                      {'val': 6, 'label': 'S', 'name': 'Sáb'},
                    ])
                      if (d['val'] != _selectedDay)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _repeatDays.contains(d['val'] as int),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _repeatDays.add(d['val'] as int);
                                  } else {
                                    _repeatDays.remove(d['val'] as int);
                                  }
                                });
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              activeColor: AppConstants.primaryColor,
                            ),
                            Text(
                              '${d['label']} (${d['name']})',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Horario (Inicio y Fin)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Inicio *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: _pickStartTime,
                          icon: const Icon(Icons.access_time_rounded, size: 18),
                          label: Text(_formatTime(_startTime)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fin *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: _pickEndTime,
                          icon: const Icon(Icons.access_time_filled_rounded, size: 18),
                          label: Text(_formatTime(_endTime)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Salón
              const Text('Salón / Aula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _roomController,
                decoration: InputDecoration(
                  hintText: 'Ej. Edificio B - Lab 3',
                  prefixIcon: const Icon(Icons.meeting_room_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
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
              : Text(isEditing ? 'Guardar' : 'Agregar'),
        ),
      ],
    );
  }
}
