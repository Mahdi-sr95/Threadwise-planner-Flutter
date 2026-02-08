import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_shell.dart';
import 'screens/courses_screen.dart';
import 'screens/add_course_screen.dart';
import 'screens/edit_course_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/settings_screen.dart';

import 'screens/calendar_screen.dart';
import 'screens/calendar_month_screen.dart';

import 'screens/saved_courses_screen.dart';

import 'state/courses_provider.dart';
import 'state/plan_provider.dart';
import 'state/settings_provider.dart';
import 'state/saved_courses_provider.dart';

// ✅ NEW (for semesters)
import 'state/semesters_provider.dart';
import 'screens/semesters_screen.dart';

/// Main entry point
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
  late final SemestersProvider _semestersProvider; // ✅ NEW
  late final CoursesProvider _coursesProvider;
  late final SavedCoursesProvider _savedCoursesProvider;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    // ✅ init semesters first
    _semestersProvider = SemestersProvider();
    await _semestersProvider.init();

    // ✅ CoursesProvider now REQUIRES semestersProvider
    _coursesProvider = CoursesProvider();
    await _coursesProvider.init();

    _savedCoursesProvider = SavedCoursesProvider();
    await _savedCoursesProvider.init();

    if (!mounted) return;
    setState(() => _initialized = true);
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
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    final from = state.uri.queryParameters['from'];
                    return EditCourseScreen(courseId: id, from: from);
                  },
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

            GoRoute(
              path: '/saved-courses',
              builder: (context, state) => const SavedCoursesScreen(),
            ),

            // ✅ NEW route
            GoRoute(
              path: '/semesters',
              builder: (context, state) => const SemestersScreen(),
            ),
          ],
        ),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _semestersProvider), // ✅ NEW
        ChangeNotifierProvider.value(value: _coursesProvider),
        ChangeNotifierProvider(create: (_) => PlanProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider.value(value: _savedCoursesProvider),
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
