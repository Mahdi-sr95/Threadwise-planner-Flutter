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
import 'screens/calendar_screen.dart';
import 'screens/calendar_month_screen.dart';

/// Main entry point - Initializes local storage and runs the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ThreadWiseApp());
}

class ThreadWiseApp extends StatefulWidget {
  const ThreadWiseApp({super.key});

  @override
  State<ThreadWiseApp> createState() => _ThreadWiseAppState();
}

class _ThreadWiseAppState extends State<ThreadWiseApp> {
  late final CoursesProvider _coursesProvider;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }

  /// Initialize all providers with local storage
  Future<void> _initializeProviders() async {
    _coursesProvider = CoursesProvider();
    await _coursesProvider.init();

    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

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
            GoRoute(
              path: '/plan',
              builder: (context, state) => const PlanScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const CalendarScreen(),
            ),

            GoRoute(
              path: '/calendar/month',
              builder: (context, state) => const CalendarMonthScreen(),
            ),
          ],
        ),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _coursesProvider),
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
