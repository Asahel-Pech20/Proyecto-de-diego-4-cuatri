import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../auth/login_screen.dart';
import 'api_settings_dialog.dart';
import 'battery_guide_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  Future<void> _deleteAccount() async {
    final parentNavigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _DeleteAccountDialog(
        onSuccess: () {
          if (!mounted) return;
          parentNavigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Tu cuenta ha sido eliminada correctamente.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onError: (msg) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        title: const Text('Ajustes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          // Tarjeta de perfil
          if (user != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppConstants.primaryColor,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: const TextStyle(fontSize: 13, color: AppConstants.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Sección General
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'GENERAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppConstants.textMuted,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_ethernet_rounded, color: AppConstants.primaryColor),
                  title: const Text('Configurar servidor', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(ApiConfig.instance.baseUrl, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppConstants.textMuted),
                  onTap: () async {
                    await ApiSettingsDialog.show(context);
                    if (mounted) setState(() {});
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.battery_charging_full_rounded, color: Colors.amber.shade800),
                  title: const Text('Guía de batería', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Para que no se pierdan tus recordatorios', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppConstants.textMuted),
                  onTap: () => BatteryGuideDialog.show(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sección Sesión y Cuenta
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'CUENTA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppConstants.textMuted,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: Colors.orange.shade800),
                  title: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Salir de tu cuenta en este dispositivo', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppConstants.textMuted),
                  onTap: _logout,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: Colors.red.shade700),
                  title: Text(
                    'Borrar mi cuenta',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade700),
                  ),
                  subtitle: const Text(
                    'Eliminar permanentemente todos tus datos del servidor',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: Colors.red.shade400),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  final void Function(String message) onError;

  const _DeleteAccountDialog({
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  late final TextEditingController _textController;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = _textController.text.trim() == 'BORRAR';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 28),
          const SizedBox(width: 10),
          const Text('Borrar mi cuenta', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acción es definitiva e irreversible. Se eliminarán permanentemente todas tus materias, tareas, horarios, faltas y calificaciones del servidor.',
              style: TextStyle(fontSize: 13, color: AppConstants.textColor),
            ),
            const SizedBox(height: 14),
            const Text(
              'Para confirmar, escribe BORRAR a continuación:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              autofocus: true,
              enabled: !_isDeleting,
              decoration: InputDecoration(
                hintText: 'BORRAR',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red.shade700, width: 2),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_isDeleting) ...[
              const SizedBox(height: 16),
              const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                    ),
                    SizedBox(width: 10),
                    Text('Eliminando cuenta...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (!isConfirmed || _isDeleting)
              ? null
              : () async {
                  setState(() => _isDeleting = true);
                  final nav = Navigator.of(context);

                  try {
                    await ApiService.instance.deleteMe();
                    await NotificationService.instance.cancelAll();
                    await DatabaseService.instance.clearAll();
                    await StorageService.instance.clearAll();

                    if (!mounted) return;
                    nav.pop();
                    widget.onSuccess();
                  } on ApiException catch (e) {
                    if (!mounted) return;
                    setState(() => _isDeleting = false);
                    nav.pop();

                    final msg = e.statusCode == 0
                        ? 'Se requiere conexión a internet para borrar la cuenta. Tus datos locales se conservan.'
                        : (e.message.isNotEmpty ? e.message : 'Error al eliminar la cuenta');
                    widget.onError(msg);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isDeleting = false);
                    nav.pop();
                    widget.onError('Se requiere conexión a internet para borrar la cuenta: $e');
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Borrar mi cuenta'),
        ),
      ],
    );
  }
}
