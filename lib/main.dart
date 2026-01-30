import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_shell.dart';
import 'screens/courses_screen.dart';
import 'screens/add_course_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/settings_screen.dart';

import 'state/courses_provider.dart';
import 'state/plan_provider.dart';
import 'state/settings_provider.dart';

void main() {
  runApp(const ThreadWiseApp());
}

class ThreadWiseApp extends StatelessWidget {
  const ThreadWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/courses',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/courses',
              builder: (context, state) => const CoursesScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const AddCourseScreen(),
                ),
              ],
            ),
            GoRoute(path: '/plan', builder: (context, state) => const PlanScreen()),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CoursesProvider(),
        ),
        ChangeNotifierProvider(create: (_) => PlanProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp.router(
        title: 'ThreadWise Planner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.indigo,
        ),
        routerConfig: router,
      ),
    );
  }
}
