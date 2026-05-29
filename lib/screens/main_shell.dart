import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_task_app/providers/task_providers.dart';
import 'package:voice_task_app/services/notification_action_handler.dart';
import '../core/haptics/app_haptics.dart';
import 'home/task_list_screen.dart';
import 'calendar/calendar_screen.dart';
import 'settings/settings_screen.dart';
import 'query/query_screen.dart';
import 'suggestions/suggestions_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize notification action handlers
    final handler = NotificationActionHandler(ref);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handler.init(context);
    });
  }

  void _onTap(int index) {
    AppHaptics.navigate();
    setState(() => _currentIndex = index);
  }

  void _onFabPressed() {
    AppHaptics.tap();
    Navigator.pushNamed(context, '/record');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          TaskListScreen(),
          CalendarScreen(),
          QueryScreen(),
          SuggestionsScreen(),
          SettingsScreen(),
        ],
      ),
      floatingActionButton: _PulsingMicFab(onPressed: _onFabPressed),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTap,
      ),
    );
  }
}

/// Bottom navigation bar with 3 destinations.
/// Center FAB is provided by Scaffold.floatingActionButton.
class _BottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _BottomBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_rounded),
          selectedIcon: Icon(Icons.home),
          label: 'Tasks',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_rounded),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Calendar',
        ),
        NavigationDestination(
          icon: Icon(Icons.question_answer_rounded),
          selectedIcon: Icon(Icons.question_answer),
          label: 'Ask',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_rounded),
          selectedIcon: Icon(Icons.auto_awesome),
          label: 'Suggestions',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_rounded),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}

/// Pulsing mic FAB with glow animation.
class _PulsingMicFab extends StatefulWidget {
  final VoidCallback onPressed;
  const _PulsingMicFab({required this.onPressed});

  @override
  State<_PulsingMicFab> createState() => _PulsingMicFabState();
}

class _PulsingMicFabState extends State<_PulsingMicFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(
                  alpha: 0.3 + (0.2 * _pulseAnimation.value),
                ),
                blurRadius: 16 + (8 * _pulseAnimation.value),
                spreadRadius: 2 + (2 * _pulseAnimation.value),
              ),
            ],
          ),
          child: child,
        );
      },
      child: FloatingActionButton(
        onPressed: widget.onPressed,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 6,
        child: const Icon(Icons.mic_rounded, size: 32),
      ),
    );
  }
}
