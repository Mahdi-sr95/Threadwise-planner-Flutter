import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:threadwise_planner/app_shell.dart';
import 'package:threadwise_planner/screens/calendar_screen.dart';
import 'package:threadwise_planner/screens/courses_screen.dart';
import 'package:threadwise_planner/screens/plan_screen.dart';
import 'package:threadwise_planner/screens/settings_screen.dart';
import 'package:threadwise_planner/state/courses_provider.dart';
import 'package:threadwise_planner/state/plan_provider.dart';
import 'package:threadwise_planner/state/saved_courses_provider.dart';
import 'package:threadwise_planner/state/semesters_provider.dart';
import 'package:threadwise_planner/state/settings_provider.dart';

Future<void> pumpAndSettleBounded(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 50),
  int maxPumps = 80,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (!tester.binding.hasScheduledFrame) return;
  }
  throw TestFailure('pumpAndSettleBounded: UI never settled.');
}

Widget testApp({
  required SemestersProvider semestersProvider,
  required CoursesProvider coursesProvider,
  String initialLocation = '/courses',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/courses', builder: (_, __) => const CoursesScreen()),
          GoRoute(path: '/plan', builder: (_, __) => const PlanScreen()),
          GoRoute(
            path: '/calendar',
            builder: (_, __) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: semestersProvider),
      ChangeNotifierProvider.value(value: coursesProvider),
      ChangeNotifierProvider(create: (_) => SavedCoursesProvider()),
      ChangeNotifierProvider(create: (_) => PlanProvider()),
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Bottom nav routes to Courses / Plan / Calendar / Settings', (
    tester,
  ) async {
    final semProv = SemestersProvider();
    await semProv.init();

    final coursesProv = CoursesProvider();
    await coursesProv.init();
    coursesProv.setSelectedSemester(semProv.selectedSemesterId);

    await tester.pumpWidget(
      testApp(
        semestersProvider: semProv,
        coursesProvider: coursesProv,
        initialLocation: '/courses',
      ),
    );
    await pumpAndSettleBounded(tester);

    expect(find.widgetWithText(AppBar, 'Courses'), findsOneWidget);

    await tester.tap(find.text('Plan'));
    await pumpAndSettleBounded(tester);
    expect(find.widgetWithText(AppBar, 'Study Plan'), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await pumpAndSettleBounded(tester);
    expect(find.widgetWithText(AppBar, 'Calendar'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await pumpAndSettleBounded(tester);
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

    await tester.tap(find.text('Courses'));
    await pumpAndSettleBounded(tester);
    expect(find.widgetWithText(AppBar, 'Courses'), findsOneWidget);
  });
}
