import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app/models/schedule.dart';
import 'package:app/models/subject.dart';
import 'package:app/models/task_item.dart';
import 'package:app/providers/auth_provider.dart';
import 'package:app/providers/schedule_provider.dart';
import 'package:app/providers/subject_provider.dart';
import 'package:app/providers/task_provider.dart';
import 'package:app/screens/schedules/schedule_form_dialog.dart';
import 'package:app/screens/settings/battery_guide_dialog.dart';
import 'package:app/screens/settings/settings_screen.dart';
import 'package:app/screens/tasks/task_form_dialog.dart';
import 'package:app/services/api_service.dart';
import 'package:app/services/database_service.dart';
import 'package:app/services/notification_service.dart';
import 'package:app/services/storage_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final Map<String, String> mockSecureStorage = {};
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        final args = methodCall.arguments is Map ? methodCall.arguments as Map : {};
        final key = args['key'] as String?;
        if (methodCall.method == 'write') {
          if (key != null) mockSecureStorage[key] = args['value'] as String? ?? '';
          return null;
        } else if (methodCall.method == 'read') {
          return key != null ? mockSecureStorage[key] : null;
        } else if (methodCall.method == 'delete') {
          if (key != null) mockSecureStorage.remove(key);
          return null;
        } else if (methodCall.method == 'deleteAll') {
          mockSecureStorage.clear();
          return null;
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall methodCall) async => true,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('mx.utm.app/settings'),
      (MethodCall methodCall) async => true,
    );

    try {
      await NotificationService.instance.init();
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Pantalla de Ajustes y Borrado de Cuenta', () {
    testWidgets('Muestra opciones de Ajustes: servidor, batería, cerrar sesión y borrar cuenta', (tester) async {
      final auth = AuthProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Configurar servidor'), findsOneWidget);
      expect(find.text('Guía de batería'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('Borrar mi cuenta'), findsOneWidget);
    });

    testWidgets('Diálogo de borrar cuenta exige escribir BORRAR para habilitar confirmación', (tester) async {
      final auth = AuthProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir diálogo de borrar cuenta
      await tester.tap(find.text('Borrar mi cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Para confirmar, escribe BORRAR a continuación:'), findsOneWidget);

      // El botón debe estar deshabilitado inicialmente
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Borrar mi cuenta');
      expect(buttonFinder, findsOneWidget);
      ElevatedButton btn = tester.widget<ElevatedButton>(buttonFinder);
      expect(btn.onPressed, isNull);

      // Escribir texto incorrecto
      await tester.enterText(find.byType(TextField), 'borrar');
      await tester.pumpAndSettle();
      btn = tester.widget<ElevatedButton>(buttonFinder);
      expect(btn.onPressed, isNull);

      // Escribir exactamente "BORRAR"
      await tester.enterText(find.byType(TextField), 'BORRAR');
      await tester.pumpAndSettle();
      btn = tester.widget<ElevatedButton>(buttonFinder);
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Borrado de cuenta sin conexión muestra error y no borra base local', (tester) async {
      // Simular offline en ApiService
      ApiService.instance.client = MockClient((req) async {
        throw const SocketException('Sin conexión con el servidor');
      });

      // Insertar materia local dentro de runAsync para evitar bloquear FakeAsync
      final db = DatabaseService.instance;
      await tester.runAsync(() async {
        await db.clearAll();
        final sub = Subject(
          id: 'sub-test-offline',
          name: 'Física I',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await db.insertSubject(sub);
      });

      final auth = AuthProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Borrar mi cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'BORRAR');
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Borrar mi cuenta');
      await tester.runAsync(() async {
        await tester.tap(buttonFinder);
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Debe mostrar mensaje de error de conexión
      expect(find.textContaining('Se requiere conexión a internet para borrar la cuenta'), findsOneWidget);

      // Los datos locales NO deben haberse borrado
      await tester.runAsync(() async {
        final subjects = await db.getSubjects();
        expect(subjects.length, equals(1));
        expect(subjects.first.id, equals('sub-test-offline'));
      });
    });

    testWidgets('Borrado de cuenta con 204 limpia base local y almacenamiento', (tester) async {
      // Simular respuesta exitosa 204
      ApiService.instance.client = MockClient((req) async {
        if (req.method == 'DELETE' && req.url.path.endsWith('/api/me')) {
          return http.Response('', 204);
        }
        return http.Response('', 404);
      });

      final db = DatabaseService.instance;
      final storage = StorageService.instance;
      await tester.runAsync(() async {
        await db.clearAll();
        final sub = Subject(
          id: 'sub-test-online',
          name: 'Química',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await db.insertSubject(sub);
        await storage.saveToken('test-token');
      });

      final auth = AuthProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Borrar mi cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'BORRAR');
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Borrar mi cuenta');
      await tester.runAsync(() async {
        await tester.tap(buttonFinder);
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Debe limpiar la base local y el storage
      await tester.runAsync(() async {
        final subjects = await db.getSubjects();
        expect(subjects.isEmpty, isTrue);

        final token = await storage.getToken();
        expect(token, isNull);
      });
    });
  });

  group('2. Guía de Batería', () {
    testWidgets('Muestra pasos de configuración y botones de acción', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BatteryGuideDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Para que no se pierdan tus recordatorios'), findsOneWidget);
      expect(find.text('Abre los ajustes con el botón inferior.'), findsOneWidget);
      expect(find.text('Desactiva la optimización de batería.'), findsOneWidget);
      expect(find.text('Permite alarmas y recordatorios.'), findsOneWidget);
      expect(find.text('Abrir ajustes'), findsOneWidget);
      expect(find.text('Entendido'), findsOneWidget);
    });
  });

  group('3. Horario - Repetir en otros días', () {
    testWidgets('ScheduleFormDialog muestra checkboxes L-S al agregar clase', (tester) async {
      final subjectProvider = SubjectProvider();
      final scheduleProvider = ScheduleProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SubjectProvider>.value(value: subjectProvider),
            ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
          ],
          child: MaterialApp(
            locale: const Locale('es', 'MX'),
            supportedLocales: const [Locale('es', 'MX'), Locale('es')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: ScheduleFormDialog(initialDay: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Repetir en otros días'), findsOneWidget);
      expect(find.byType(Checkbox), findsWidgets);
      // Hay 5 checkboxes para los otros días (Martes a Sábado, pues Lunes es el seleccionado)
      expect(find.byType(Checkbox), findsNWidgets(5));
    });
  });

  group('4. Captura Rápida en 3 Toques', () {
    test('findNextClassStartTime calcula la próxima clase futura de una materia', () {
      final now = DateTime(2026, 11, 23, 9, 30); // Lunes 9:30 AM
      final schedules = [
        Schedule(
          id: 's1',
          subjectId: 'sub-calc',
          dayOfWeek: 1, // Lunes
          startTime: '08:00',
          endTime: '10:00',
          createdAt: now,
          updatedAt: now,
        ),
        Schedule(
          id: 's2',
          subjectId: 'sub-calc',
          dayOfWeek: 3, // Miércoles
          startTime: '08:00',
          endTime: '10:00',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // A las 9:30 AM el lunes, la clase de las 8:00 ya empezó, la siguiente es el miércoles a las 8:00 AM
      final nextClass = TaskFormDialog.findNextClassStartTime(schedules, 'sub-calc', from: now);
      expect(nextClass, isNotNull);
      expect(nextClass!.weekday, equals(3)); // Miércoles
      expect(nextClass.hour, equals(8));
      expect(nextClass.minute, equals(0));
    });

    test('findNextClassStartTime cuando la clase de hoy es más tarde', () {
      final now = DateTime(2026, 11, 23, 7, 0); // Lunes 7:00 AM
      final schedules = [
        Schedule(
          id: 's1',
          subjectId: 'sub-calc',
          dayOfWeek: 1, // Lunes
          startTime: '08:00',
          endTime: '10:00',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final nextClass = TaskFormDialog.findNextClassStartTime(schedules, 'sub-calc', from: now);
      expect(nextClass, isNotNull);
      expect(nextClass!.weekday, equals(1)); // Lunes
      expect(nextClass.hour, equals(8));
      expect(nextClass.minute, equals(0));
    });
  });

  group('5. Bug Selector de Hora', () {
    testWidgets('Selector de hora inicializado en 23:59 y selección de hora', (tester) async {
      TimeOfDay selectedTime = const TimeOfDay(hour: 23, minute: 59);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es', 'MX'),
          supportedLocales: const [Locale('es', 'MX'), Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: selectedTime,
                    initialEntryMode: TimePickerEntryMode.dial,
                  );
                  if (picked != null) {
                    selectedTime = picked;
                  }
                },
                child: const Text('Abrir Selector'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Selector'));
      await tester.pumpAndSettle();

      // Debe abrir el diálogo del selector de hora sin errores
      expect(find.byType(TimePickerDialog), findsOneWidget);

      // Confirmar con el botón de aceptación del diálogo
      final confirmBtn = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextButton),
      ).last;
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // El diálogo se cierra limpiamente
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(selectedTime, const TimeOfDay(hour: 23, minute: 59));
    });
  });

  group('6. Abrir Tarea al Tocar Notificación', () {
    testWidgets('handleNotificationTap abre diálogo de la tarea especificada por taskId', (tester) async {
      final db = DatabaseService.instance;
      await tester.runAsync(() async {
        await db.clearAll();

        final sub = Subject(
          id: 'sub-notif',
          name: 'Programación Móvil',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await db.insertSubject(sub);

        final task = TaskItem(
          id: 'task-notif-123',
          subjectId: 'sub-notif',
          title: 'Proyecto Flutter Notificaciones',
          dueAt: DateTime.now().add(const Duration(hours: 4)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await db.insertTask(task);
      });

      final subjectProvider = SubjectProvider();
      final scheduleProvider = ScheduleProvider();
      final taskProvider = TaskProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SubjectProvider>.value(value: subjectProvider),
            ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
            ChangeNotifierProvider<TaskProvider>.value(value: taskProvider),
          ],
          child: MaterialApp(
            navigatorKey: NotificationService.navigatorKey,
            locale: const Locale('es', 'MX'),
            supportedLocales: const [Locale('es', 'MX'), Locale('es')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: Text('Pantalla Principal'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simular llegada de notificación con el ID de la tarea como payload dentro de runAsync
      await tester.runAsync(() async {
        NotificationService.handleNotificationTap('task-notif-123');
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Debe abrirse TaskFormDialog con los datos de esa tarea
      expect(find.byType(TaskFormDialog), findsOneWidget);
      expect(find.text('Proyecto Flutter Notificaciones'), findsOneWidget);
    });
  });
}
