import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/app_controller.dart';
import 'package:saathi_app/src/l10n/app_text.dart';
import 'package:saathi_app/src/models.dart';
import 'package:saathi_app/src/screens/health_summary_screen.dart';
import 'package:saathi_app/src/screens/medicines_screen.dart';
import 'package:saathi_app/src/screens/more_screen.dart';
import 'package:saathi_app/src/screens/next_appointment_screen.dart';
import 'package:saathi_app/src/screens/patient_dashboard_screen.dart';
import 'package:saathi_app/src/screens/prescription_screen.dart';
import 'package:saathi_app/src/screens/settings_screen.dart';
import 'package:saathi_app/src/screens/visit_history_screen.dart';
import 'package:saathi_app/src/theme.dart';
import 'package:saathi_app/src/widgets/draggable_listen_ball.dart';
import 'package:saathi_app/src/widgets/language_switch.dart';
import 'package:saathi_app/src/widgets/saathi_bottom_navigation.dart';

/// End-to-end widget coverage for the patient dashboard and the screens it
/// opens. This exercises real navigation, real localisation swapping, and real
/// state transitions — not just that the widgets construct without throwing.
void main() {
  setUpAll(() {
    // Required so that FlutterSecureStorage platform channels resolve in tests.
    // Without this, async reads inside AppController.fetchClinicalVisits()
    // and initialize() hang indefinitely causing pumpAndSettle timeouts.
    FlutterSecureStorage.setMockInitialValues({});
  });

  // Mirrors the ListenableBuilder(locale: controller.language.locale) wiring
  // in main.dart, so language-switch tests see the same locale-rebuild
  // behaviour the real app has.
  Widget harness(AppController controller, Widget home) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        theme: buildSaathiTheme(),
        locale: controller.language.locale,
        supportedLocales: AppText.supportedLocales,
        localizationsDelegates: const [
          AppText.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );
  }

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

  Future<void> pumpDashboard(WidgetTester tester, AppController controller) {
    return tester.pumpWidget(
      harness(controller, PatientDashboardScreen(controller: controller)),
    );
  }

  testWidgets('dashboard shows the appointment, all four tiles, emergency '
      'and the language switch', (tester) async {
    final controller = linkedController();
    await pumpDashboard(tester, controller);
    await tester.pump(); // allow async clinical load to settle

    // Hero card: no appointment booked (appointments not yet in backend).
    expect(find.text('Appointments'), findsOneWidget);
    // No mock hospital name now — appointments are unimplemented.
    expect(find.text('City Care Hospital'), findsNothing);

    // The 2x2 grid.
    expect(find.text('My Prescription'), findsOneWidget);
    expect(find.text('Medicines'), findsOneWidget);
    expect(find.text('Appointments'), findsOneWidget);
    expect(find.text('Health Summary'), findsOneWidget);

    expect(find.text('EMERGENCY'), findsOneWidget);
    expect(find.text('Tap for immediate help'), findsOneWidget);

    // The language pill sits in the header, labelled with the language
    // currently in force.
    expect(find.byType(LanguageSwitchButton), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    // Today's dose is deliberately not here — it lives on the Medicines tile.
    expect(find.text("Today's Medicine"), findsNothing);

    // There is no bottom navigation bar any more — Home is this screen,
    // Appointments and Medicines are grid tiles, and More lives behind the
    // menu button in the header.
    expect(find.byType(SaathiBottomNavigation), findsNothing);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

    // And the floating Listen ball, which replaces the header's old Listen button.
    expect(find.byType(DraggableListenBall), findsOneWidget);
  });

  testWidgets("Medicines tile navigates to MedicinesScreen", (tester) async {
    final controller = linkedController();
    await pumpDashboard(tester, controller);
    await tester.pump();

    await tester.tap(find.text('Medicines'));
    await tester.pumpAndSettle();

    expect(find.byType(MedicinesScreen), findsOneWidget);
  });

  testWidgets('the Medicines tile opens the medicines screen', (tester) async {
    final controller = linkedController();
    await pumpDashboard(tester, controller);
    await tester.pump();

    await tester.tap(find.text('Medicines'));
    await tester.pumpAndSettle();

    expect(find.byType(MedicinesScreen), findsOneWidget);
  });

  testWidgets('hero appointment card opens the appointment screen', (
    tester,
  ) async {
    final controller = linkedController();
    await pumpDashboard(tester, controller);
    await tester.pump();

    await tester.tap(find.text('Appointments'));
    await tester.pumpAndSettle();

    expect(find.byType(NextAppointmentScreen), findsOneWidget);
    // Appointments are not yet implemented — the screen shows "No upcoming
    // appointment". No mock doctor name.
    expect(find.text('No appointment booked yet'), findsOneWidget);
  });

  testWidgets(
    'prescription tile opens prescription screen — shows empty state in tests',
    (tester) async {
      final controller = linkedController();
      await pumpDashboard(tester, controller);
      await tester.pump();

      await tester.tap(find.text('My Prescription'));
      await tester.pumpAndSettle();

      expect(find.byType(PrescriptionScreen), findsOneWidget);
      // No real API server in tests — empty state is the expected result.
      expect(find.text('No Reports Available'), findsOneWidget);
      // No mock data should be visible.
      expect(find.text('Type 2 Diabetes Mellitus'), findsNothing);
    },
  );

  testWidgets('health summary tile opens the implemented care plan screen', (
    tester,
  ) async {
    final controller = linkedController();
    await pumpDashboard(tester, controller);
    await tester.pump();

    await tester.ensureVisible(find.text('Health Summary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Health Summary'));
    await tester.pumpAndSettle();

    expect(find.byType(HealthSummaryScreen), findsOneWidget);
    expect(find.text('Upload Report'), findsOneWidget);
  });

  testWidgets(
    'the header menu button reaches past visits — shows empty state in tests',
    (tester) async {
      final controller = linkedController();
      await pumpDashboard(tester, controller);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(MoreScreen), findsOneWidget);

      await tester.tap(find.text('Past Visits'));
      await tester.pumpAndSettle();
      expect(find.byType(VisitHistoryScreen), findsOneWidget);

      // No real server in tests — empty state is expected.
      expect(find.text('No visits yet'), findsOneWidget);
      // No mock visit cards — "Blood pressure check" should not appear.
      expect(find.text('Blood pressure check'), findsNothing);
    },
  );

  testWidgets(
    'visit detail download state machine works when opened directly',
    (tester) async {
      // Build VisitDetailScreen directly with a ClinicalVisit fixture so we
      // can test the download state machine without a real server.
      final controller = linkedController();
      const visit = PatientVisit(
        visitId: 1,
        patientId: 1,
        visitDate: '2024-01-15',
        reason: 'Follow-up',
      );
      const cv = ClinicalVisit(
        visit: visit,
        doctorName: 'Dr. Test',
        diagnosis: 'Test Diagnosis',
      );
      await tester.pumpWidget(
        harness(
          controller,
          VisitDetailScreen(clinicalVisit: cv, controller: controller),
        ),
      );
      await tester.pump();

      expect(find.text('DOWNLOAD'), findsOneWidget);
      await tester.tap(find.text('DOWNLOAD'));
      await tester.pump(); // downloading state
      expect(find.text('Saving…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 950));
      expect(find.text('Saved to your phone'), findsOneWidget);
    },
  );

  testWidgets(
    'emergency requires confirmation and cancel does not navigate away',
    (tester) async {
      final controller = linkedController();
      await pumpDashboard(tester, controller);
      await tester.pump();

      await tester.ensureVisible(find.text('EMERGENCY'));
      await tester.tap(find.text('EMERGENCY'));
      await tester.pumpAndSettle();

      expect(find.text('Call the hospital for help?'), findsOneWidget);
      await tester.tap(find.text('NO, GO BACK'));
      await tester.pumpAndSettle();

      // Back on the dashboard, nothing was dialled.
      expect(find.text('EMERGENCY'), findsOneWidget);
      expect(find.text('Calling the hospital…'), findsNothing);
    },
  );

  testWidgets(
    'emergency confirm opens the calling screen, which auto-returns',
    (tester) async {
      final controller = linkedController();
      await pumpDashboard(tester, controller);
      await tester.pump();

      await tester.ensureVisible(find.text('EMERGENCY'));
      await tester.tap(find.text('EMERGENCY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('YES, CALL NOW'));
      // Not pumpAndSettle here: the calling screen's pulsing icon uses a
      // repeating AnimationController, which never "settles" by design.
      // Step through the dialog-pop and screen-push transitions explicitly
      // instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Calling the hospital…'), findsOneWidget);

      // The calling screen pops itself ~2s after appearing, then the pop
      // transition itself takes a few hundred ms — pump forward in small
      // steps so we land cleanly after both instead of guessing one big gap.
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Calling the hospital…'), findsNothing);
      expect(find.text('EMERGENCY'), findsOneWidget);
    },
  );

  testWidgets('language switch changes visible text on the dashboard', (
    tester,
  ) async {
    final controller = linkedController();
    await pumpDashboard(tester, controller);
    await tester.pump();

    expect(find.text('Appointments'), findsOneWidget);

    // Straight from the dashboard header — no navigating away, no settings
    // screen in between.
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('हिन्दी'), findsOneWidget);
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    // The dashboard itself is now in Hindi, without leaving it.
    expect(find.byType(PatientDashboardScreen), findsOneWidget);
    expect(find.text('मुलाक़ातें'), findsOneWidget); // Appointments
    expect(find.text('आपातकाल'), findsOneWidget); // EMERGENCY
    expect(find.text('Appointments'), findsNothing);
    // And the pill now reports the language in force.
    expect(find.text('हिन्दी'), findsOneWidget);
  });

  testWidgets('the header menu button reaches Settings', (tester) async {
    final controller = linkedController();
    await pumpDashboard(tester, controller);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('dashboard does not overflow at a large system font scale', (
    tester,
  ) async {
    final controller = linkedController();
    // A small phone (Pixel-class 320dp-wide logical viewport) at 2x text —
    // the combination this audience is most likely to be running.
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(
        controller,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: PatientDashboardScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // At 2x the grid drops to a single column rather than squeezing two tiles
    // into 320dp.
    expect(find.text('My Prescription'), findsOneWidget);
    expect(find.text('Health Summary'), findsOneWidget);
  });
}
