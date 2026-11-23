import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/subject.dart';
import '../../providers/subject_provider.dart';
import '../../widgets/color_picker_widget.dart';
import '../../widgets/custom_text_field.dart';

class SubjectFormScreen extends StatefulWidget {
  final Subject? subject;

  const SubjectFormScreen({super.key, this.subject});

  @override
  State<SubjectFormScreen> createState() => _SubjectFormScreenState();
}

class _SubjectFormScreenState extends State<SubjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _teacherController;
  late TextEditingController _maxAbsencesController;
  late TextEditingController _passingGradeController;
  late TextEditingController _gradeScaleController;
  String? _selectedColor = AppConstants.defaultSubjectColors.first;
  bool _isSaving = false;

  bool get isEditing => widget.subject != null;

  @override
  void initState() {
    super.initState();
    final s = widget.subject;
    _nameController = TextEditingController(text: s?.name ?? '');
    _teacherController = TextEditingController(text: s?.teacher ?? '');
    _maxAbsencesController = TextEditingController(text: s?.maxAbsences?.toString() ?? '');
    _passingGradeController = TextEditingController(
      text: s != null ? s.passingGrade.toString() : '8.0',
    );
    _gradeScaleController = TextEditingController(
      text: s != null ? s.gradeScale.toString() : '10.0',
    );
    if (s != null) {
      _selectedColor = s.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _maxAbsencesController.dispose();
    _passingGradeController.dispose();
    _gradeScaleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<SubjectProvider>();
    final maxAbsences = int.tryParse(_maxAbsencesController.text.trim());
    final passingGrade = double.tryParse(_passingGradeController.text.trim()) ?? 8.0;
    final gradeScale = double.tryParse(_gradeScaleController.text.trim()) ?? 10.0;

    bool success;
    if (isEditing) {
      success = await provider.updateSubject(
        id: widget.subject!.id,
        name: _nameController.text.trim(),
        teacher: _teacherController.text.trim().isEmpty ? null : _teacherController.text.trim(),
        color: _selectedColor,
        maxAbsences: maxAbsences,
        passingGrade: passingGrade,
        gradeScale: gradeScale,
      );
    } else {
      success = await provider.createSubject(
        name: _nameController.text.trim(),
        teacher: _teacherController.text.trim().isEmpty ? null : _teacherController.text.trim(),
        color: _selectedColor,
        maxAbsences: maxAbsences,
        passingGrade: passingGrade,
        gradeScale: gradeScale,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Materia actualizada' : 'Materia creada con éxito'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al guardar la materia'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Materia' : 'Nueva Materia',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                controller: _nameController,
                label: 'Nombre de la materia *',
                hint: 'Ej. Sistemas Distribuidos',
                prefixIcon: Icons.book_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingresa el nombre de la materia';
                  }
                  if (v.trim().length > 100) {
                    return 'El nombre no puede exceder 100 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _teacherController,
                label: 'Profesor / Docente',
                hint: 'Ej. Dr. Carlos Hernández',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 20),
              ColorPickerWidget(
                selectedColorHex: _selectedColor,
                onColorSelected: (hex) {
                  setState(() => _selectedColor = hex);
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Parámetros académicos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textColor),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _maxAbsencesController,
                label: 'Límite de faltas permitido',
                hint: 'Ej. 5 (dejar vacío si no hay límite)',
                prefixIcon: Icons.event_busy_outlined,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final n = int.tryParse(v);
                    if (n == null || n < 0) {
                      return 'Ingresa un número entero positivo';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _passingGradeController,
                      label: 'Calificación aprobatoria',
                      hint: '8.0',
                      prefixIcon: Icons.check_circle_outline,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        final n = double.tryParse(v);
                        if (n == null || n < 0) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _gradeScaleController,
                      label: 'Escala máxima',
                      hint: '10.0',
                      prefixIcon: Icons.grade_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    isEditing ? 'Guardar Cambios' : 'Crear Materia',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
