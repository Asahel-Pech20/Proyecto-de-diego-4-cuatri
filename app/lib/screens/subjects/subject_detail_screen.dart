import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/academic_calculator.dart';
import '../../models/grade.dart';
import '../../models/subject.dart';
import '../../models/subject_summary.dart';
import '../../providers/absence_provider.dart';
import '../../providers/grade_provider.dart';
import '../../providers/subject_provider.dart';
import 'subject_form_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;

  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Subject _currentSubject;
  double _simulatedScore = 8.0;

  @override
  void initState() {
    super.initState();
    _currentSubject = widget.subject;
    _tabController = TabController(length: 3, vsync: this);
    _simulatedScore = _currentSubject.passingGrade;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    context.read<AbsenceProvider>().loadAbsences(_currentSubject.id);
    context.read<GradeProvider>().loadGrades(_currentSubject.id);
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

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar materia?'),
        content: Text(
          'Se eliminará "${_currentSubject.name}" y todos sus datos asociados (horario, tareas, faltas y calificaciones). Esta acción no se puede deshacer.',
        ),
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

    if (confirm != true || !mounted) return;

    final provider = context.read<SubjectProvider>();
    final success = await provider.deleteSubject(_currentSubject.id);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materia eliminada'), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al eliminar la materia'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================
  // MODALES Y ACCIONES DE FALTAS
  // ==========================================

  Future<void> _registerTodayAbsence() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final provider = context.read<AbsenceProvider>();

    if (provider.absences.any((a) => a.date == todayStr)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya existe una falta registrada para hoy en esta materia.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await provider.createAbsence(
      subjectId: _currentSubject.id,
      date: todayStr,
      subject: _currentSubject,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta de hoy registrada'), behavior: SnackBarBehavior.floating),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _showCustomAbsenceDialog() async {
    DateTime selectedDate = DateTime.now();
    final noteController = TextEditingController();
    bool isJustified = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.event_busy_rounded, color: AppConstants.primaryColor),
              SizedBox(width: 8),
              Text('Registrar Falta'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fecha de la falta *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogCtx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        const Icon(Icons.calendar_today_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Motivo / Nota (opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    hintText: 'Ej. Cita médica, transporte...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: const Text('Falta Justificada', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Las justificadas no cuentan para el límite.', style: TextStyle(fontSize: 12)),
                  value: isJustified,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => isJustified = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                final provider = context.read<AbsenceProvider>();
                final messenger = ScaffoldMessenger.of(context);

                if (provider.absences.any((a) => a.date == dateStr)) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Ya existe una falta registrada para el $dateStr en esta materia.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final ok = await provider.createAbsence(
                  subjectId: _currentSubject.id,
                  date: dateStr,
                  justified: isJustified,
                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                  subject: _currentSubject,
                );

                if (!mounted) return;
                if (ok) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Falta registrada correctamente'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (provider.errorMessage != null) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(provider.errorMessage!), behavior: SnackBarBehavior.floating),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MODALES Y ACCIONES DE CALIFICACIONES
  // ==========================================

  Future<void> _showGradeDialog({Grade? grade}) async {
    final nameController = TextEditingController(text: grade?.name ?? '');
    final weightController = TextEditingController(text: grade != null ? '${grade.weight}' : '');
    final scoreController = TextEditingController(text: grade?.score != null ? '${grade!.score}' : '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.grade_rounded, color: AppConstants.primaryColor),
            SizedBox(width: 8),
            Text(grade != null ? 'Editar Evaluación' : 'Nueva Evaluación'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nombre de la evaluación *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Ej. Parcial 1, Proyecto, Prácticas',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Porcentaje que vale (%) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Ej. 30 (para 30%)',
                  suffixText: '%',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Calificación obtenida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('Dejar en blanco si aún no se presenta.', style: TextStyle(fontSize: 12, color: AppConstants.textMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: scoreController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Ej. 8.5 (Escala 0 a ${_currentSubject.gradeScale})',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final weight = double.tryParse(weightController.text.trim());
              final scoreText = scoreController.text.trim();
              final score = scoreText.isNotEmpty ? double.tryParse(scoreText) : null;

              if (name.isEmpty || weight == null || weight <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nombre y porcentaje válido son obligatorios')),
                );
                return;
              }

              Navigator.pop(ctx);
              final provider = context.read<GradeProvider>();

              if (grade != null) {
                await provider.updateGrade(
                  id: grade.id,
                  subjectId: _currentSubject.id,
                  name: name,
                  weight: weight,
                  score: score,
                );
              } else {
                await provider.createGrade(
                  subjectId: _currentSubject.id,
                  name: name,
                  weight: weight,
                  score: score,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(_currentSubject.color);
    final absenceProvider = context.watch<AbsenceProvider>();
    final gradeProvider = context.watch<GradeProvider>();

    // CÁLCULOS 100% LOCALES (OFFLINE FIRST)
    final absenceSummary = AcademicCalculator.calculateAbsences(
      absences: absenceProvider.absences,
      maxAbsences: _currentSubject.maxAbsences,
    );

    final gradeSummary = AcademicCalculator.calculateGrades(
      grades: gradeProvider.grades,
      passingGrade: _currentSubject.passingGrade,
      gradeScale: _currentSubject.gradeScale,
    );

    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        title: Text(_currentSubject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar materia',
            onPressed: () async {
              final provider = context.read<SubjectProvider>();
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SubjectFormScreen(subject: _currentSubject),
                ),
              );
              if (!mounted) return;
              final updated = provider.subjects.firstWhere(
                (s) => s.id == _currentSubject.id,
                orElse: () => _currentSubject,
              );
              setState(() => _currentSubject = updated);
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar materia',
            onPressed: _confirmDelete,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          tabs: const [
            Tab(icon: Icon(Icons.calculate_outlined), text: 'Simulador'),
            Tab(icon: Icon(Icons.event_busy_outlined), text: 'Faltas'),
            Tab(icon: Icon(Icons.grade_outlined), text: 'Evaluaciones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: SIMULADOR Y RESUMEN ACADÉMICO LOCAL
          _buildSimulatorTab(absenceSummary, gradeSummary, gradeProvider.grades),

          // TAB 2: GESTIÓN DE FALTAS
          _buildAbsencesTab(absenceProvider),

          // TAB 3: EVALUACIONES Y CALIFICACIONES
          _buildGradesTab(gradeProvider),
        ],
      ),
    );
  }

  // ==========================================
  // VISTA TAB 1: SIMULADOR LOCAL
  // ==========================================
  Widget _buildSimulatorTab(AbsenceSummary absences, GradeSummary grades, List<Grade> gradeList) {
    Color statusColor = Colors.blue;
    String statusText = 'Evaluaciones en curso';
    IconData statusIcon = Icons.hourglass_top_rounded;

    switch (grades.status) {
      case 'secured':
        statusColor = Colors.green;
        statusText = '¡Aprobada garantizada! Ya aseguraste la calificación mínima aun si sacas 0 en lo restante.';
        statusIcon = Icons.verified_rounded;
        break;
      case 'possible':
        statusColor = Colors.blue;
        statusText = grades.neededOnPending != null
            ? 'Necesitas promediar ${grades.neededOnPending!.toStringAsFixed(2)} en lo pendiente para aprobar con ${_currentSubject.passingGrade}.'
            : 'En curso.';
        statusIcon = Icons.auto_graph_rounded;
        break;
      case 'impossible':
        statusColor = Colors.red;
        statusText = 'Imposible alcanzar la calificación mínima (${_currentSubject.passingGrade}) en ordinario.';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Materia cursada y aprobada con ${grades.accumulated.toStringAsFixed(1)}.';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusText = 'Materia cursada y no aprobada (${grades.accumulated.toStringAsFixed(1)}).';
        statusIcon = Icons.close_rounded;
        break;
      case 'no-data':
      default:
        statusColor = Colors.grey;
        statusText = 'Aún no hay evaluaciones registradas en esta materia.';
        statusIcon = Icons.info_outline;
        break;
    }

    final projectedGrade = AcademicCalculator.simulateProjectedGrade(
      grades: gradeList,
      simulatedPendingScore: _simulatedScore,
      gradeScale: _currentSubject.gradeScale,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Alerta de Faltas
          if (absences.exceeded)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Límite de faltas superado. Estás en situación no aprobatoria por inasistencias.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else if (absences.atRisk)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¡Atención! Te queda ${absences.remaining} falta(s) antes de alcanzar el límite permitido.',
                      style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Tarjeta de Asistencias Resumen
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Asistencia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        _currentSubject.maxAbsences != null
                            ? '${absences.count - absences.justified} de ${_currentSubject.maxAbsences} faltas'
                            : '${absences.count} faltas (sin límite)',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppConstants.primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Injustificadas', '${absences.count - absences.justified}', Colors.red.shade700),
                      _buildStatItem('Justificadas', '${absences.justified}', Colors.green.shade700),
                      _buildStatItem(
                        'Restantes',
                        absences.remaining != null ? '${absences.remaining! < 0 ? 0 : absences.remaining}' : '∞',
                        (absences.remaining ?? 5) <= 1 ? Colors.red : Colors.blue.shade700,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Tarjeta de Estatus de Calificación
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Puntos asegurados', '${grades.accumulated.toStringAsFixed(1)} / ${_currentSubject.gradeScale}', AppConstants.primaryColor),
                      _buildStatItem('Promedio actual', grades.currentAverage.toStringAsFixed(1), Colors.blue.shade700),
                      _buildStatItem('Evaluado', '${grades.gradedWeight.toStringAsFixed(0)}%', Colors.purple.shade700),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Deslizador interactivo "¿Y si saco...?"
          if (grades.pendingWeight > 0)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: AppConstants.primaryColor),
                        SizedBox(width: 8),
                        Text('¿Y si saco...?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Simula tu calificación final según lo que obtengas en el ${grades.pendingWeight.toStringAsFixed(0)}% restante:',
                      style: const TextStyle(fontSize: 12, color: AppConstants.textMuted),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Calificación simulada:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _simulatedScore.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _simulatedScore,
                      min: 0.0,
                      max: _currentSubject.gradeScale,
                      divisions: (_currentSubject.gradeScale * 10).toInt(),
                      activeColor: AppConstants.primaryColor,
                      label: _simulatedScore.toStringAsFixed(1),
                      onChanged: (val) {
                        setState(() => _simulatedScore = (val * 10).round() / 10);
                      },
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Calificación final resultante:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text(
                          '$projectedGrade / ${_currentSubject.gradeScale}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: projectedGrade >= _currentSubject.passingGrade ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      projectedGrade >= _currentSubject.passingGrade
                          ? '🎉 ¡Aprobarías la materia!'
                          : '⚠️ No alcanzarías la calificación mínima (${_currentSubject.passingGrade}).',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: projectedGrade >= _currentSubject.passingGrade ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // VISTA TAB 2: FALTAS
  // ==========================================
  Widget _buildAbsencesTab(AbsenceProvider absenceProvider) {
    final absences = absenceProvider.absences;

    return Column(
      children: [
        // Barra superior de acciones rápidas
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _registerTodayAbsence,
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const Text('Falta de hoy (1 toque)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showCustomAbsenceDialog,
                icon: const Icon(Icons.event_note_rounded),
                label: const Text('Otra fecha'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        // Lista de faltas registradas
        Expanded(
          child: absences.isEmpty
              ? const Center(
                  child: Text('No tienes faltas registradas en esta materia.', style: TextStyle(color: AppConstants.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: absences.length,
                  itemBuilder: (ctx, index) {
                    final item = absences[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              item.justified ? Icons.check_circle_outline : Icons.cancel_outlined,
                              color: item.justified ? Colors.green : Colors.red,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.date,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  if (item.note != null && item.note!.isNotEmpty)
                                    Text(
                                      item.note!,
                                      style: const TextStyle(fontSize: 12, color: AppConstants.textMuted),
                                    ),
                                ],
                              ),
                            ),
                            // Switch justificada
                            Row(
                              children: [
                                Text(
                                  item.justified ? 'Justificada' : 'Injustificada',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: item.justified ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                                Switch(
                                  value: item.justified,
                                  onChanged: (_) => absenceProvider.toggleJustified(item, subject: _currentSubject),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                              onPressed: () => absenceProvider.deleteAbsence(item.id, _currentSubject.id, subject: _currentSubject),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // VISTA TAB 3: CALIFICACIONES
  // ==========================================
  Widget _buildGradesTab(GradeProvider gradeProvider) {
    final grades = gradeProvider.grades;
    final totalWeight = gradeProvider.totalWeight;
    final is100 = gradeProvider.isWeight100;

    return Column(
      children: [
        // Aviso de suma de porcentajes si != 100%
        if (grades.isNotEmpty && !is100)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La suma de las ponderaciones es ${totalWeight.toStringAsFixed(1)}% (se recomienda 100%).',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

        // Botón para agregar evaluación
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showGradeDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar Evaluación / Examen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),

        // Lista de evaluaciones
        Expanded(
          child: grades.isEmpty
              ? const Center(
                  child: Text('No hay evaluaciones registradas aún.', style: TextStyle(color: AppConstants.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: grades.length,
                  itemBuilder: (ctx, index) {
                    final item = grades[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Valor: ${item.weight.toStringAsFixed(0)}% del curso'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: item.isPending
                                    ? Colors.grey.shade100
                                    : (item.score! >= _currentSubject.passingGrade ? Colors.green.shade50 : Colors.red.shade50),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: item.isPending
                                      ? Colors.grey.shade300
                                      : (item.score! >= _currentSubject.passingGrade ? Colors.green : Colors.red),
                                ),
                              ),
                              child: Text(
                                item.isPending ? 'Pendiente' : '${item.score}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: item.isPending
                                      ? Colors.grey.shade700
                                      : (item.score! >= _currentSubject.passingGrade ? Colors.green.shade900 : Colors.red.shade900),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showGradeDialog(grade: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => gradeProvider.deleteGrade(item.id, _currentSubject.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppConstants.textMuted)),
      ],
    );
  }
}
