import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../config/constants.dart';
import '../../services/api_service.dart';

class ApiSettingsDialog extends StatefulWidget {
  const ApiSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ApiSettingsDialog(),
    );
  }

  @override
  State<ApiSettingsDialog> createState() => _ApiSettingsDialogState();
}

class _ApiSettingsDialogState extends State<ApiSettingsDialog> {
  late TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;
  bool? _isSuccess;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.instance.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _isSuccess = null;
    });

    final previous = ApiConfig.instance.baseUrl;
    await ApiConfig.instance.setBaseUrl(_urlController.text.trim());

    final ok = await ApiService.instance.checkHealth();

    if (!mounted) return;

    if (!ok) {
      await ApiConfig.instance.setBaseUrl(previous);
    }

    setState(() {
      _isTesting = false;
      _isSuccess = ok;
      _testResult = ok
          ? '¡Conexión exitosa con el servidor!'
          : 'No se pudo conectar al servidor en esa URL.';
    });
  }

  Future<void> _save() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) return;

    await ApiConfig.instance.setBaseUrl(newUrl);
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('URL del servidor actualizada: $newUrl'),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.dns_rounded, color: AppConstants.primaryColor),
          SizedBox(width: 8),
          Text('Configurar Servidor'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona o escribe la URL base de la API:',
              style: TextStyle(fontSize: 13, color: AppConstants.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL de la API',
                hintText: 'http://10.0.2.2:3000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(
                  label: const Text('Emulador (10.0.2.2)'),
                  onPressed: () {
                    _urlController.text = AppConstants.defaultEmulatorUrl;
                  },
                ),
                ActionChip(
                  label: const Text('Localhost (3000)'),
                  onPressed: () {
                    _urlController.text = AppConstants.defaultLocalhostUrl;
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_testResult != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_isSuccess ?? false) ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_isSuccess ?? false) ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (_isSuccess ?? false) ? Icons.check_circle : Icons.error,
                      color: (_isSuccess ?? false) ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          fontSize: 12,
                          color: (_isSuccess ?? false) ? Colors.green[900] : Colors.red[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _isTesting ? null : _testConnection,
          icon: _isTesting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering),
          label: const Text('Probar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
