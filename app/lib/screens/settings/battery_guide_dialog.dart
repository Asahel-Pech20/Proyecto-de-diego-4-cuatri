import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/constants.dart';

class BatteryGuideDialog extends StatelessWidget {
  const BatteryGuideDialog({super.key});

  static const MethodChannel _settingsChannel = MethodChannel('mx.utm.app/settings');

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const BatteryGuideDialog(),
    );
  }

  static Future<void> openSettings() async {
    try {
      await _settingsChannel.invokeMethod('openBatterySettings');
    } catch (e) {
      debugPrint('Error abriendo ajustes de batería: $e');
      try {
        await _settingsChannel.invokeMethod('openAppSettings');
      } catch (e2) {
        debugPrint('Error abriendo ajustes de app: $e2');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.battery_alert_rounded,
              color: AppConstants.primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Para que no se pierdan tus recordatorios',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En Android (especialmente en Xiaomi, Samsung, Motorola y Huawei), el sistema puede suspender las aplicaciones en segundo plano para ahorrar batería, bloqueando los recordatorios programados.',
              style: TextStyle(fontSize: 13, color: AppConstants.textColor),
            ),
            const SizedBox(height: 14),
            const Text(
              'Sigue estos pasos recomendados:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildStep(
              number: '1',
              title: 'Abre los ajustes con el botón inferior.',
              subtitle: 'Te llevará a los ajustes del sistema de la app.',
            ),
            const SizedBox(height: 8),
            _buildStep(
              number: '2',
              title: 'Desactiva la optimización de batería.',
              subtitle: 'Elige "Sin restricciones" o "No optimizar" para MiSemestre UTM.',
            ),
            const SizedBox(height: 8),
            _buildStep(
              number: '3',
              title: 'Permite alarmas y recordatorios.',
              subtitle: 'Verifica que el permiso de alarmas exactas esté concedido.',
            ),
            const SizedBox(height: 8),
            _buildStep(
              number: '4',
              title: 'Activa el inicio automático (opcional).',
              subtitle: 'Recomendado en capas como MIUI/HyperOS para persistir tras reiniciar.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            openSettings();
          },
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: const Text('Abrir ajustes'),
          style: TextButton.styleFrom(
            foregroundColor: AppConstants.primaryColor,
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Entendido'),
        ),
      ],
    );
  }

  Widget _buildStep({required String number, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: AppConstants.primaryColor,
          child: Text(
            number,
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppConstants.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
