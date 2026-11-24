// Validación mínima del proyecto final: casos con datos inválidos.
// Los formularios deben mostrar mensajes claros y NO enviar nada al servidor.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/screens/auth/login_screen.dart';
import 'package:app/screens/auth/register_screen.dart';

Widget _wrap(Widget child) => MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(home: child),
    );

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  group('Validaciones con datos inválidos', () {
    testWidgets('Login con campos vacíos muestra ambos mensajes', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
      await tester.pump();

      expect(find.text('Ingresa tu correo'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    });

    testWidgets('Login con correo mal escrito pide un correo válido', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.enterText(_field('Correo electrónico'), 'ana-sin-arroba');
      await tester.enterText(_field('Contraseña'), 'algo1234');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
      await tester.pump();

      expect(find.text('Ingresa un correo válido'), findsOneWidget);
    });

    testWidgets('Registro rechaza contraseña corta y confirmación distinta', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const RegisterScreen()));
      await tester.enterText(_field('Nombre completo'), 'Ana López');
      await tester.enterText(_field('Correo electrónico'), 'ana@utm.edu.mx');
      await tester.enterText(_field('Contraseña (mínimo 8 caracteres)'), '123');
      await tester.enterText(_field('Confirmar contraseña'), '456');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Registrarse'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Registrarse'));
      await tester.pump();

      expect(find.text('La contraseña debe tener al menos 8 caracteres'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });

    testWidgets('Registro con nombre vacío no avanza', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const RegisterScreen()));
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Registrarse'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Registrarse'));
      await tester.pump();

      expect(find.text('Ingresa tu nombre'), findsOneWidget);
      expect(find.text('Ingresa tu correo'), findsOneWidget);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });
}
