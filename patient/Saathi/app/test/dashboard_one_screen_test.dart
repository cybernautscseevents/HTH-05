import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/app_controller.dart';
import 'package:saathi_app/src/l10n/app_text.dart';
import 'package:saathi_app/src/models.dart';
import 'package:saathi_app/src/screens/patient_dashboard_screen.dart';
import 'package:saathi_app/src/theme.dart';
import 'package:saathi_app/src/widgets/dashboard_cards.dart';
import 'package:saathi_app/src/widgets/draggable_listen_ball.dart';
import 'package:saathi_app/src/widgets/saathi_bottom_navigation.dart';

/// The dashboard has to fit on one screen, with nothing to scroll to, at the
/// system's normal font scale.
///
/// Measured against a *real* typeface, not the test framework's default. The
/// default test font draws every glyph as a full em square, so a card that fits
/// comfortably on a phone wraps onto extra lines under test and this file would
/// report a layout problem that does not exist on any device. Loading the
/// platform's own UI font (and its Indic companion for Hindi and Kannada) is
/// what makes these numbers mean anything.
///
/// The threshold is deliberately 1.0x-1.15x and no higher. Above that the app
/// scrolls instead, because the alternative — shrinking text to keep everything
/// on one screen — would take legibility away from exactly the low-vision
/// patients who turned the font size up in the first place. That is a trade
/// this app does not make; see the note in [PatientDashboardScreen].
void main() {
  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    for (final font in {
      'RealSans': r'C:\Windows\Fonts\segoeui.ttf',
      'RealIndic': r'C:\Windows\Fonts\Nirmala.ttc',
    }.entries) {
      final file = File(font.value);
      if (!file.existsSync()) continue;
      final loader = FontLoader(font.key)
        ..addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
      await loader.load();
    }
  });

  /// Phone sizes the one-screen guarantee covers. Everything from a 360x640
  /// compact Android upwards, which is the great majority of handsets in use.
  /// Removing the bottom navigation bar (the floating Listen ball needs no
  /// space of its own — it overlays the page) freed enough height to bring
  /// 360x640 into the fitting range; it used to scroll by up to 19px.
  ///
  /// Only 320x568 — an iPhone-SE-1st-gen-class screen — is deliberately
  /// absent: the content genuinely does not fit there at a legible size, so
  /// that one scrolls. It is still covered for overflow by
  /// dashboard_responsive_test.
  const sizes = <String, Size>{
    'compact 360x640': Size(360, 640),
    'budget android 360x800': Size(360, 800),
    'compact 384x854': Size(384, 854),
    'typical 393x852': Size(393, 852),
    'large 412x915': Size(412, 915),
  };

  Future<ScrollPosition> pumpDashboard(
    WidgetTester tester,
    Size size,
    double scale,
    AppLanguage language,
  ) async {
    final controller = AppController(storage: const FlutterSecureStorage());
    controller.patient = const Patient(
      id: 1,
      uid: 'SAA-2608-A1B2C3',
      name: 'Lakshmi Iyer',
      age: 63,
      condition: 'Type 2 Diabetes Mellitus',
    );
    controller.status = AppStatus.patientLinked;
    controller.language = language;

    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final base = buildSaathiTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: base.copyWith(
          textTheme: base.textTheme.apply(
            fontFamily: 'RealSans',
            fontFamilyFallback: const ['RealIndic'],
          ),
        ),
        locale: language.locale,
        supportedLocales: AppText.supportedLocales,
        localizationsDelegates: const [
          AppText.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: PatientDashboardScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    return tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
  }

  for (final entry in sizes.entries) {
    for (final language in AppLanguage.values) {
      testWidgets('${entry.key} ${language.code}: no scrolling at 1.0x', (
        tester,
      ) async {
        final position = await pumpDashboard(
          tester,
          entry.value,
          1.0,
          language,
        );

        expect(tester.takeException(), isNull);
        // Nothing below the fold: the whole page is already on screen.
        expect(
          position.maxScrollExtent,
          0.0,
          reason:
              '${entry.key} in ${language.englishLabel} needs '
              '${position.maxScrollExtent.toStringAsFixed(1)}px of scrolling '
              'at the normal font scale',
        );
      });
    }
  }

  testWidgets(
    'everything the design calls non-negotiable is on screen at once',
    (tester) async {
      await pumpDashboard(
        tester,
        const Size(393, 852),
        1.0,
        AppLanguage.english,
      );

      final viewport = tester.getSize(find.byType(Scrollable).first);
      double bottomOf(Finder finder) =>
          tester.getRect(finder.first).bottom -
          tester.getRect(find.byType(Scrollable).first).top;

      // Each of the three must not merely exist — it must be painted inside the
      // visible viewport, with no scrolling.
      for (final finder in [
        find.byKey(const Key('askSaathiBar')),
        find.byType(DashboardFeatureCard).at(3), // the last grid tile
        find.byType(EmergencyCard),
      ]) {
        expect(bottomOf(finder), lessThanOrEqualTo(viewport.height + .01));
      }
      // There is no bottom navigation bar to sit below any more — Home is
      // this screen, Appointments/Medicines are grid tiles, and More is
      // behind the header's menu button. The floating Listen ball takes its
      // place as the one thing that floats above this content.
      expect(find.byType(SaathiBottomNavigation), findsNothing);
      expect(find.byType(DraggableListenBall), findsOneWidget);
    },
  );

  testWidgets('a large system font scale is allowed to scroll rather than '
      'shrink the text', (tester) async {
    final position = await pumpDashboard(
      tester,
      const Size(393, 852),
      2.0,
      AppLanguage.english,
    );

    expect(tester.takeException(), isNull);
    // The point of the test: at 2x the page is longer than the screen and that
    // is the correct outcome. If this ever reads 0 again, something started
    // scaling text down to fit, which is the one thing this layout must not do.
    expect(position.maxScrollExtent, greaterThan(0.0));

    // Still fully reachable, and still not overflowing.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('emergency card uses the full dashboard height', (tester) async {
    for (final size in const [Size(360, 800), Size(393, 852), Size(412, 915)]) {
      await pumpDashboard(tester, size, 1.0, AppLanguage.english);
      final viewport = tester.getRect(find.byType(Scrollable).first);
      final emergency = tester.getRect(find.byType(EmergencyCard));
      expect(
        viewport.bottom - emergency.bottom,
        lessThanOrEqualTo(.01),
        reason: 'dashboard left dead space above navigation at $size',
      );
    }
  });

  testWidgets('1.15x still fits on a large phone', (tester) async {
    for (final language in AppLanguage.values) {
      final position = await pumpDashboard(
        tester,
        const Size(412, 915),
        1.15,
        language,
      );
      expect(
        position.maxScrollExtent,
        0.0,
        reason:
            '412x915 in ${language.englishLabel} scrolls at 1.15x by '
            '${position.maxScrollExtent.toStringAsFixed(1)}px',
      );
    }
  });
}
