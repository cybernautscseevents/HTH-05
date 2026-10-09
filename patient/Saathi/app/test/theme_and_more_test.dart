import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/app_controller.dart';
import 'package:saathi_app/src/l10n/app_text.dart';
import 'package:saathi_app/src/models.dart';
import 'package:saathi_app/src/screens/medicine_reminders_screen.dart';
import 'package:saathi_app/src/screens/more_screen.dart';
import 'package:saathi_app/src/screens/next_appointment_screen.dart';
import 'package:saathi_app/src/screens/patient_dashboard_screen.dart';
import 'package:saathi_app/src/screens/prescription_screen.dart';
import 'package:saathi_app/src/screens/settings_screen.dart';
import 'package:saathi_app/src/screens/visit_history_screen.dart';
import 'package:saathi_app/src/settings.dart';
import 'package:saathi_app/src/theme.dart';
import 'package:saathi_app/src/widgets/dashboard_cards.dart';
import 'package:saathi_app/src/widgets/draggable_listen_ball.dart';
import 'package:saathi_app/src/widgets/saathi_bottom_navigation.dart';

void main() {
  setUpAll(() {
    // Required so that FlutterSecureStorage platform channels resolve in tests.
    // Without this, FutureBuilder-based screens (VisitHistoryScreen,
    // PrescriptionScreen, MedicineRemindersScreen) hang on
    // controller.fetchClinicalVisits() and pumpAndSettle times out.
    FlutterSecureStorage.setMockInitialValues({});
  });

  AppController linkedController() {
    final controller = AppController(storage: const FlutterSecureStorage());
    controller.patient = const Patient(
      id: 1,
      uid: 'SAA-2608-A1B2C3',
      name: 'Lakshmi Iyer',
      age: 63,
      condition: 'Type 2 Diabetes Mellitus',
    );
    controller.status = AppStatus.patientLinked;
    return controller;
  }

  Widget harness(AppController controller, Widget home, {double scale = 1}) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        theme: buildSaathiTheme(
          highContrast: controller.highContrast,
          boldText: controller.boldText,
        ),
        darkTheme: buildSaathiDarkTheme(
          highContrast: controller.highContrast,
          boldText: controller.boldText,
        ),
        themeMode: switch (controller.themeMode) {
          SaathiThemeMode.system => ThemeMode.system,
          SaathiThemeMode.light => ThemeMode.light,
          SaathiThemeMode.dark => ThemeMode.dark,
        },
        locale: controller.language.locale,
        supportedLocales: AppText.supportedLocales,
        localizationsDelegates: const [
          AppText.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            boldText: controller.boldText,
          ),
          child: child!,
        ),
        home: home,
      ),
    );
  }

  testWidgets(
    'dark dashboard renders in every language at normal and large text',
    (tester) async {
      for (final language in AppLanguage.values) {
        for (final scale in [1.0, 1.5]) {
          final controller = linkedController()
            ..themeMode = SaathiThemeMode.dark
            ..language = language;
          tester.view.physicalSize = const Size(393 * 3, 852 * 3);
          tester.view.devicePixelRatio = 3;
          await tester.pumpWidget(
            harness(
              controller,
              PatientDashboardScreen(controller: controller),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
          expect(scaffold.backgroundColor, SaathiColors.dark.page);
        }
      }
      addTearDown(tester.view.reset);
    },
  );

  testWidgets(
    'all linked patient destinations render in dark mode across languages',
    (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      for (final language in AppLanguage.values) {
        for (final scale in [1.0, 1.5]) {
          final controller = linkedController()
            ..themeMode = SaathiThemeMode.dark
            ..language = language;
          final screens = <Widget>[
            PatientDashboardScreen(controller: controller),
            MoreScreen(controller: controller),
            SettingsScreen(controller: controller),
            HelpScreen(controller: controller),
            SupportScreen(controller: controller),
            PrivacyScreen(controller: controller),
            MedicineRemindersScreen(controller: controller),
            NextAppointmentScreen(controller: controller),
            PrescriptionScreen(controller: controller),
            VisitHistoryScreen(controller: controller),
          ];

          for (final screen in screens) {
            await tester.pumpWidget(harness(controller, screen, scale: scale));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '${screen.runtimeType} failed in ${language.code} '
                  'at ${scale}x',
            );
          }
        }
      }
    },
  );

  testWidgets('settings changes theme mode, bold text and high contrast', (
    tester,
  ) async {
    final controller = linkedController();
    await tester.pumpWidget(
      harness(controller, SettingsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Dark'));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(controller.themeMode, SaathiThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );

    await tester.ensureVisible(find.text('Bold text'));
    await tester.tap(find.text('Bold text'));
    await tester.pumpAndSettle();
    expect(controller.boldText, isTrue);

    await tester.ensureVisible(find.text('High contrast'));
    await tester.tap(find.text('High contrast'));
    await tester.pumpAndSettle();
    expect(controller.highContrast, isTrue);
  });

  testWidgets('Support and Privacy & Security rows navigate to their own '
      'screens', (tester) async {
    final controller = linkedController();
    await tester.pumpWidget(
      harness(controller, MoreScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('more-support-row')));
    await tester.pumpAndSettle();
    expect(find.byType(SupportScreen), findsOneWidget);
    // Support is the hospital's own contact details, not a copy of them.
    expect(find.text('Your linked hospital'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('more-privacy-row')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(find.textContaining('kept by your hospital'), findsOneWidget);
  });

  testWidgets('More is a list menu and not a duplicate dashboard', (
    tester,
  ) async {
    final controller = linkedController()..themeMode = SaathiThemeMode.dark;
    await tester.pumpWidget(
      harness(controller, MoreScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('more-help-row')), findsOneWidget);
    expect(find.byKey(const Key('more-settings-row')), findsOneWidget);
    expect(find.byKey(const Key('more-visits-row')), findsOneWidget);
    expect(find.byKey(const Key('more-support-row')), findsOneWidget);
    expect(find.byKey(const Key('more-privacy-row')), findsOneWidget);
    expect(find.byType(DashboardFeatureCard), findsNothing);
    expect(find.byType(AppointmentCard), findsNothing);
    // No bottom bar on this screen — the patient goes back via the app bar's
    // back arrow instead. The floating Listen ball takes its place.
    expect(find.byType(SaathiBottomNavigation), findsNothing);
    expect(find.byType(DraggableListenBall), findsOneWidget);
    expect(find.text('More'), findsWidgets);
  });

  testWidgets('How to use this app leads the More menu', (tester) async {
    final controller = linkedController();
    await tester.pumpWidget(
      harness(controller, MoreScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    final rowOrder = [
      'more-help-row',
      'more-settings-row',
      'more-visits-row',
      'more-support-row',
      'more-privacy-row',
    ];
    final tops = [
      for (final key in rowOrder) tester.getTopLeft(find.byKey(Key(key))).dy,
    ];
    expect(
      tops,
      List<double>.from(tops)..sort(),
      reason: 'the menu rows are not in the expected top-to-bottom order',
    );
  });

  testWidgets('More menu rows show no subcaption — icon, title and chevron '
      'only', (tester) async {
    final controller = linkedController();
    await tester.pumpWidget(
      harness(controller, MoreScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    for (final forbidden in [
      'Language, text size',
      'Old reports and medicines',
      'Call your hospital for help',
      'Who can see your information',
    ]) {
      expect(
        find.textContaining(forbidden, findRichText: true),
        findsNothing,
        reason: '"$forbidden" is a subcaption and must not be painted',
      );
    }
  });

  testWidgets('all five More menu rows are exactly the same size', (
    tester,
  ) async {
    final controller = linkedController();
    await tester.pumpWidget(
      harness(controller, MoreScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    final rects = [
      for (final key in [
        'more-help-row',
        'more-settings-row',
        'more-visits-row',
        'more-support-row',
        'more-privacy-row',
      ])
        tester.getRect(find.byKey(Key(key))),
    ];
    double round(double v) => (v * 100).round() / 100;
    expect(
      rects.map((r) => round(r.height)).toSet().length,
      1,
      reason:
          'More menu rows have mismatched heights: '
          '${rects.map((r) => r.height).toList()}',
    );
    expect(
      rects.map((r) => round(r.width)).toSet().length,
      1,
      reason:
          'More menu rows have mismatched widths: '
          '${rects.map((r) => r.width).toList()}',
    );
  });
}
