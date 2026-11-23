import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'home/home_screen.dart';
import 'schedules/schedule_screen.dart';
import 'settings/battery_guide_dialog.dart';
import 'tasks/tasks_screen.dart';
import 'subjects/subjects_screen.dart';

class MainShell extends StatefulWidget {
  final int initialTab;

  const MainShell({super.key, this.initialTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.instance.checkAndRequestExactAlarmPermission();
      NotificationService.processPendingNotificationTap();

      final hasSeen = await StorageService.instance.hasSeenBatteryGuide();
      if (!hasSeen && mounted) {
        await BatteryGuideDialog.show(context);
        await StorageService.instance.setSeenBatteryGuide(true);
      }
    });
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigateTab: _onTabTapped),
      const ScheduleScreen(),
      const TasksScreen(),
      const SubjectsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        indicatorColor: AppConstants.primaryColor.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppConstants.primaryColor),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded, color: AppConstants.primaryColor),
            label: 'Horario',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt_rounded, color: AppConstants.primaryColor),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book_rounded, color: AppConstants.primaryColor),
            label: 'Materias',
          ),
        ],
      ),
    );
  }
}
