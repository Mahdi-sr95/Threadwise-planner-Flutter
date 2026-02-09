import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_shell.dart';
import 'screens/add_course_screen.dart';
import 'screens/calendar_month_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/courses_screen.dart';
import 'screens/edit_course_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/saved_courses_screen.dart';
import 'screens/semesters_screen.dart';
import 'screens/settings_screen.dart';
import 'state/courses_provider.dart';
import 'state/plan_provider.dart';
import 'state/saved_courses_provider.dart';
import 'state/semesters_provider.dart';
import 'state/settings_provider.dart';
import 'services/notifications_service.dart';

/// Main entry point for the ThreadWise Planner app.
/// Initializes providers and sets up routing.
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
  // Global providers used across the app.
  late final SemestersProvider _semestersProvider;
  late final CoursesProvider _coursesProvider;
  late final SavedCoursesProvider _savedCoursesProvider;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }

  /// Initializes all app-level providers and keeps their state in sync.
  Future<void> _initializeProviders() async {
    // Initialize semesters first so other providers can depend on it.
    _semestersProvider = SemestersProvider();
    await _semestersProvider.init();

    // CoursesProvider stores courses per semester.
    _coursesProvider = CoursesProvider();
    await _coursesProvider.init();

    // Ensure CoursesProvider starts with the selected semester.
    _coursesProvider.setSelectedSemester(_semestersProvider.selectedSemesterId);

    await NotificationsService.instance.init();

    // Saved courses are derived from previous plans.
    _savedCoursesProvider = SavedCoursesProvider();
    await _savedCoursesProvider.init();

    if (!mounted) return;
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Simple splash while providers are being initialized.
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
        // Semester selection is global.
        ChangeNotifierProvider.value(value: _semestersProvider),
        // Courses depend on the selected semester.
        ChangeNotifierProvider.value(value: _coursesProvider),
        // Saved courses used for auto-add.
        ChangeNotifierProvider.value(value: _savedCoursesProvider),
        // Planning + settings are local state.
        ChangeNotifierProvider(create: (_) => PlanProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      // Keeps CoursesProvider.semester in sync with SemestersProvider.
      child: _SemesterCoursesSync(
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
      ),
    );
  }
}

/// Widget that keeps CoursesProvider.selectedSemesterId
/// synchronized with SemestersProvider.selectedSemesterId.
class _SemesterCoursesSync extends StatefulWidget {
  final Widget child;

  const _SemesterCoursesSync({required this.child});

  @override
  State<_SemesterCoursesSync> createState() => _SemesterCoursesSyncState();
}

class _SemesterCoursesSyncState extends State<_SemesterCoursesSync> {
  SemestersProvider? _semProv;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sp = context.read<SemestersProvider>();

    if (_semProv != sp) {
      _semProv?.removeListener(_onSemesterChanged);
      _semProv = sp;
      _semProv?.addListener(_onSemesterChanged);
      _syncNow();
    }
  }

  /// Called whenever SemestersProvider changes.
  void _onSemesterChanged() {
    _syncNow();
  }

  /// Propagates the current semester selection into CoursesProvider.
  void _syncNow() {
    final sp = context.read<SemestersProvider>();
    final cp = context.read<CoursesProvider>();

    final wanted = sp.selectedSemesterId;
    if (cp.selectedSemesterId == wanted) return;

    // This will notify listeners and refresh screens using CoursesProvider.courses.
    cp.setSelectedSemester(wanted);
  }

  @override
  void dispose() {
    _semProv?.removeListener(_onSemesterChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
