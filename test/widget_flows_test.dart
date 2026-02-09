import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:threadwise_planner/app_shell.dart';
import 'package:threadwise_planner/screens/add_course_screen.dart';
import 'package:threadwise_planner/screens/calendar_screen.dart';
import 'package:threadwise_planner/screens/courses_screen.dart';
import 'package:threadwise_planner/screens/plan_screen.dart';
import 'package:threadwise_planner/screens/semesters_screen.dart';
import 'package:threadwise_planner/screens/settings_screen.dart';

import 'package:threadwise_planner/state/courses_provider.dart';
import 'package:threadwise_planner/state/plan_provider.dart';
import 'package:threadwise_planner/state/saved_courses_provider.dart';
import 'package:threadwise_planner/state/semesters_provider.dart';
import 'package:threadwise_planner/state/settings_provider.dart';

Future<void> scrollToText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Enter text into a TextField/TextFormField by its *hint text*.
Future<void> enterIntoFieldByHint(
  WidgetTester tester, {
  required String hintText,
  required String text,
}) async {
  final hint = find.text(hintText);

  // Ensure the field is built/visible
  await tester.scrollUntilVisible(
    hint,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();

  // Find InputDecorator that contains the hint
  final decorator = find.ancestor(
    of: hint.first,
    matching: find.byType(InputDecorator),
  );
  expect(decorator, findsOneWidget);

  final editable = find.descendant(
    of: decorator,
    matching: find.byType(EditableText),
  );
  expect(editable, findsOneWidget);

  await tester.tap(editable);
  await tester.pump();
  await tester.enterText(editable, text);
  await tester.pump();
}

Widget _testApp({
  required SemestersProvider semestersProvider,
  required CoursesProvider coursesProvider,
  SavedCoursesProvider? savedCoursesProvider,
  PlanProvider? planProvider,
  SettingsProvider? settingsProvider,
  String initialLocation = '/courses',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/courses',
            builder: (_, __) => const CoursesScreen(),
            routes: [
              GoRoute(path: 'add', builder: (_, __) => const AddCourseScreen()),
            ],
          ),
          GoRoute(path: '/plan', builder: (_, __) => const PlanScreen()),
          GoRoute(
            path: '/calendar',
            builder: (_, __) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/semesters',
            builder: (_, __) => const SemestersScreen(),
          ),
        ],
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: semestersProvider),
      ChangeNotifierProvider.value(value: coursesProvider),
      ChangeNotifierProvider.value(
        value: savedCoursesProvider ?? SavedCoursesProvider(),
      ),
      ChangeNotifierProvider.value(value: planProvider ?? PlanProvider()),
      ChangeNotifierProvider.value(
        value: settingsProvider ?? SettingsProvider(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Enters text into the form field that has the given visible label.
Future<void> enterIntoLabeledField(
  WidgetTester tester, {
  required String labelText,
  required String text,
}) async {
  final label = find.text(labelText);
  expect(label, findsWidgets); // can be >1 in some themes

  // Find the nearest InputDecorator above that label.
  final decorator = find.ancestor(
    of: label.first,
    matching: find.byType(InputDecorator),
  );
  expect(decorator, findsOneWidget);

  final editable = find.descendant(
    of: decorator,
    matching: find.byType(EditableText),
  );
  expect(editable, findsOneWidget);

  // Tap to focus, then enter text.
  await tester.tap(editable);
  await tester.pump();

  await tester.enterText(editable, text);
  await tester.pump();
}

/// Picks a tappable ListTile that contains the text.
Finder tappableListTileWithText(String text) {
  return find.byWidgetPredicate((w) {
    if (w is! ListTile) return false;
    if (w.onTap == null) return false;

    bool subtreeHasText(Widget ww) {
      if (ww is Text && ww.data == text) return true;
      if (ww is RichText) return ww.text.toPlainText() == text;

      if (ww is IconButton) return false;
      if (ww is ListTile) {
        return subtreeHasText(ww.title ?? const SizedBox()) ||
            subtreeHasText(ww.subtitle ?? const SizedBox());
      }

      if (ww is Row) return ww.children.any(subtreeHasText);
      if (ww is Column) return ww.children.any(subtreeHasText);
      if (ww is Wrap) return ww.children.any(subtreeHasText);
      if (ww is Padding) return subtreeHasText(ww.child ?? const SizedBox());
      if (ww is Align) return subtreeHasText(ww.child ?? const SizedBox());
      if (ww is Center) return subtreeHasText(ww.child ?? const SizedBox());
      if (ww is Container) return subtreeHasText(ww.child ?? const SizedBox());

      return false;
    }

    return subtreeHasText(w);
  }, description: 'tappable ListTile containing "$text"');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Widget - Navigation', () {
    testWidgets('Bottom nav routes to Courses / Plan / Calendar / Settings', (
      tester,
    ) async {
      final semProv = SemestersProvider();
      await semProv.init();

      final coursesProv = CoursesProvider();
      await coursesProv.init();
      coursesProv.setSelectedSemester(semProv.selectedSemesterId);

      await tester.pumpWidget(
        _testApp(
          semestersProvider: semProv,
          coursesProvider: coursesProv,
          initialLocation: '/courses',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Courses'), findsOneWidget);

      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Study Plan'), findsOneWidget);

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Calendar'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

      await tester.tap(find.text('Courses'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Courses'), findsOneWidget);
    });
  });

  testWidgets('Missing deadline blocks saving (snackbar), no navigation', (
    tester,
  ) async {
    final semProv = SemestersProvider();
    await semProv.init();

    final coursesProv = CoursesProvider();
    await coursesProv.init();
    coursesProv.setSelectedSemester(semProv.selectedSemesterId);

    await tester.pumpWidget(
      _testApp(
        semestersProvider: semProv,
        coursesProvider: coursesProv,
        initialLocation: '/courses/add',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Add Course'), findsOneWidget);

    // Scroll until manual form section is built
    await scrollToText(tester, 'Course details');

    // Fill name and hours (by hint text), skip deadline
    await enterIntoFieldByHint(
      tester,
      hintText: 'e.g., Mobile Application Development',
      text: 'Mobile App Dev',
    );

    await enterIntoFieldByHint(tester, hintText: 'e.g., 15', text: '10');

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Please select a deadline'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Add Course'), findsOneWidget);
  });

  group('Widget - Semesters', () {
    testWidgets(
      'Selecting semester + confirm returns to Courses (route changes)',
      (tester) async {
        final semProv = SemestersProvider();
        await semProv.init();
        await semProv.addSemester(name: 'Spring 2026');

        final coursesProv = CoursesProvider();
        await coursesProv.init();
        coursesProv.setSelectedSemester(semProv.selectedSemesterId);

        await tester.pumpWidget(
          _testApp(
            semestersProvider: semProv,
            coursesProvider: coursesProv,
            initialLocation: '/semesters',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.widgetWithText(AppBar, 'Semesters'), findsOneWidget);

        final springTile = tappableListTileWithText('Spring 2026');
        expect(springTile, findsOneWidget);

        await tester.tap(springTile);
        await tester.pumpAndSettle();

        // Semesters screen uses Confirm/Continue label depending on change
        final confirm = find.text('Confirm');
        final cont = find.text('Continue');

        if (confirm.evaluate().isNotEmpty) {
          await tester.tap(confirm.first);
        } else {
          await tester.tap(cont.first);
        }
        await tester.pumpAndSettle();

        expect(find.widgetWithText(AppBar, 'Courses'), findsOneWidget);
        expect(find.textContaining('Semester: Spring 2026'), findsOneWidget);
      },
    );
  });
}
