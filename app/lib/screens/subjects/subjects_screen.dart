import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/subject.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subject_provider.dart';
import '../../services/database_service.dart';
import '../auth/login_screen.dart';
import '../settings/api_settings_dialog.dart';
import '../settings/settings_screen.dart';
import 'subject_detail_screen.dart';
import 'subject_form_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubjectProvider>().loadSubjects();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _logout() async {
    final hasPending = await DatabaseService.instance.hasPendingChanges();
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Estás seguro de que deseas cerrar tu sesión?'),
            if (hasPending) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tienes cambios guardados en el teléfono que aún no se han sincronizado con el servidor. Al cerrar sesión, la base local se reiniciará y esos cambios se perderán.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPending ? Colors.red.shade700 : AppConstants.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(hasPending ? 'Cerrar sesión y descartar' : 'Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await context.read<AuthProvider>().logout();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjectProvider = context.watch<SubjectProvider>();
    final authProvider = context.watch<AuthProvider>();

    final allSubjects = subjectProvider.subjects;
    final filteredSubjects = _searchQuery.isEmpty
        ? allSubjects
        : allSubjects
            .where((s) =>
                s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (s.teacher?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
            .toList();

    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Materias',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            if (authProvider.currentUser != null)
              Text(
                authProvider.currentUser!.name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (subjectProvider.isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'Sincronizar ahora',
              onPressed: () => subjectProvider.syncData(),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else if (value == 'server') {
                ApiSettingsDialog.show(context);
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20, color: AppConstants.primaryColor),
                    SizedBox(width: 10),
                    Text('Ajustes'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'server',
                child: Row(
                  children: [
                    Icon(Icons.settings_ethernet, size: 20, color: AppConstants.primaryColor),
                    SizedBox(width: 10),
                    Text('Configurar Servidor'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SubjectFormScreen()),
          );
        },
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Materia'),
      ),
      body: RefreshIndicator(
        onRefresh: () => subjectProvider.loadSubjects(),
        child: Column(
          children: [
            // Barra de búsqueda si hay materias
            if (allSubjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar por materia o docente...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppConstants.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
              ),

            // Lista de materias o estados vacío/cargando
            Expanded(
              child: subjectProvider.isLoading && allSubjects.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredSubjects.isEmpty
                      ? _buildEmptyState(isFiltering: _searchQuery.isNotEmpty)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filteredSubjects.length,
                          itemBuilder: (ctx, index) {
                            final subject = filteredSubjects[index];
                            return _buildSubjectCard(context, subject);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isFiltering}) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltering ? Icons.search_off_rounded : Icons.auto_stories_outlined,
                size: 64,
                color: AppConstants.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isFiltering ? 'No se encontraron coincidencias' : 'Aún no tienes materias registradas',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConstants.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltering
                  ? 'Intenta con otro término de búsqueda'
                  : 'Registra tus materias del semestre para organizar tus horarios, tareas, asistencias y calificaciones.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppConstants.textMuted),
            ),
            if (!isFiltering) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubjectFormScreen()),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar primera materia'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, Subject subject) {
    final color = _parseHex(subject.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SubjectDetailScreen(subject: subject),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Indicador visual de color
                  Container(
                    width: 14,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Nombre y profesor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textColor,
                          ),
                        ),
                        if (subject.teacher != null && subject.teacher!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 15, color: AppConstants.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  subject.teacher!,
                                  style: const TextStyle(fontSize: 13, color: AppConstants.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Menú contextual
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded, color: AppConstants.textMuted),
                    onSelected: (action) {
                      if (action == 'edit') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SubjectFormScreen(subject: subject),
                          ),
                        );
                      } else if (action == 'delete') {
                        _confirmDeleteSubject(context, subject);
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
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Chips de información académica
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildChip(
                    icon: Icons.check_circle_outline,
                    label: 'Mín: ${subject.passingGrade}',
                    color: Colors.blue.shade50,
                    textColor: Colors.blue.shade800,
                  ),
                  _buildChip(
                    icon: Icons.grade_outlined,
                    label: 'Escala: ${subject.gradeScale}',
                    color: Colors.purple.shade50,
                    textColor: Colors.purple.shade800,
                  ),
                  _buildChip(
                    icon: Icons.event_busy_outlined,
                    label: subject.maxAbsences != null
                        ? 'Máx faltas: ${subject.maxAbsences}'
                        : 'Faltas sin límite',
                    color: Colors.orange.shade50,
                    textColor: Colors.orange.shade800,
                  ),
                  if (subject.syncStatus != 'synced')
                    _buildChip(
                      icon: Icons.cloud_upload_outlined,
                      label: 'Pendiente sync',
                      color: Colors.amber.shade100,
                      textColor: Colors.brown.shade800,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSubject(BuildContext context, Subject subject) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar materia?'),
        content: Text('Se eliminará "${subject.name}" y todos sus datos relacionados.'),
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

    final provider = context.read<SubjectProvider>();
    final ok = await provider.deleteSubject(subject.id);

    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materia eliminada'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}
