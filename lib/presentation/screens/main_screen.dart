import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'calculator/quick_calculator_screen.dart';
import 'inventory/inventory_screen.dart';
import 'workout/workout_screen.dart';
import 'settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  final _workoutKey  = GlobalKey<WorkoutContentState>();
  final _inventoryKey = GlobalKey<InventoryContentState>();

  static const _titles = ['Workout', 'Inventory'];

  void _onFabPressed() {
    if (_index == 0) _workoutKey.currentState?.showAddWorkoutSheet();
    if (_index == 1) _inventoryKey.currentState?.showAddInventorySheet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _titles[_index],
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 24),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calculate_outlined, size: 24),
            tooltip: 'Quick Calculator',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const QuickCalculatorScreen(),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          WorkoutContent(key: _workoutKey),
          InventoryContent(key: _inventoryKey),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onFabPressed,
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Workout',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Inventory',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
