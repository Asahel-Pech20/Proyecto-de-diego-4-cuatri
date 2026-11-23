import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'MiSemestre UTM';

  // URLs del Backend
  static const String defaultEmulatorUrl = 'http://10.0.2.2:3000';
  static const String defaultLocalhostUrl = 'http://localhost:3000';

  // Claves de almacenamiento
  static const String keyToken = 'auth_token';
  static const String keyUser = 'user_data';
  static const String keyApiBaseUrl = 'api_base_url';
  static const String keyLastSyncTime = 'last_sync_time';

  // Paleta de colores institucionales y de diseño UTM
  static const Color primaryColor = Color(0xFF7A1B29); // Vino UTM
  static const Color primaryDark = Color(0xFF56111C);
  static const Color accentColor = Color(0xFFD49E35); // Dorado / Ocre UTM
  static const Color surfaceColor = Color(0xFFF9F9FB);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);

  // Colores predeterminados para materias
  static const List<String> defaultSubjectColors = [
    '#7A1B29', // Vino
    '#2563EB', // Azul Real
    '#059669', // Esmeralda
    '#D97706', // Ámbar oscuro
    '#7C3AED', // Púrpura
    '#DC2626', // Rojo
    '#0891B2', // Cian
    '#4F46E5', // Índigo
    '#DB2777', // Rosa
    '#4B5563', // Grafito
  ];
}
