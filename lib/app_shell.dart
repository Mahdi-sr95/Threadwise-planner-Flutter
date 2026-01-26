import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _indexFromLocation(String location) {
    if (location.startsWith('/plan')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0; //courses
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final idx = _indexFromLocation(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/courses');
              break;
            case 1:
              context.go('/plan');
              break;
            case 2:
              context.go('/settings');
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.view_agenda), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
