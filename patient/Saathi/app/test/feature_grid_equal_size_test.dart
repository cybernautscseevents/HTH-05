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

/// The 2x2 feature grid must render four identically-sized rectangles.
///
/// "My Prescription" and "Appointments" fit their title on one line;
/// "Medicine Reminders" and "Health Summary" wrap to two. Before this test
/// existed, the grid only matched card heights *within* a row (via
/// [IntrinsicHeight] in `_GridRow`), so the row holding a two-line title grew
/// to fit it while the other row stayed short — the top row measured 160px
/// and the bottom row 138px, a visible 22px mismatch. Measured against a real
/// typeface, not the test framework's default — see the note on
/// dashboard_one_screen_test.dart for why that distinction matters here.
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

  Future<void> pumpDashboard(
    WidgetTester tester,
    Size size,
    AppLanguage language,
    bool dark,
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

    final base = dark ? buildSaathiDarkTheme() : buildSaathiTheme();
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
        home: PatientDashboardScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  const sizes = <String, Size>{
    '360x800': Size(360, 800),
    '393x852': Size(393, 852),
    '412x915': Size(412, 915),
  };

  for (final entry in sizes.entries) {
    for (final language in AppLanguage.values) {
      for (final dark in [false, true]) {
        testWidgets('all four grid cards are the same size — ${entry.key} '
            '${language.code} ${dark ? 'dark' : 'light'}', (tester) async {
          await pumpDashboard(tester, entry.value, language, dark);

          final cards = find.byType(DashboardFeatureCard);
          expect(cards, findsNWidgets(4));

          final rects = [
            for (var i = 0; i < 4; i++) tester.getRect(cards.at(i)),
          ];
          // Rounded to a hundredth of a pixel: layout arithmetic on this
          // path chains several subtractions (screen height minus safe-area
          // insets minus padding), which can leave two logically-identical
          // heights a few units of double precision apart — invisible on
          // screen, but not equal under exact `==`.
          double round(double v) => (v * 100).round() / 100;
          final heights = rects.map((r) => round(r.height)).toSet();
          final widths = rects.map((r) => round(r.width)).toSet();

          expect(
            heights.length,
            1,
            reason:
                'grid cards have mismatched heights: '
                '${rects.map((r) => r.height).toList()}',
          );
          expect(
            widths.length,
            1,
            reason:
                'grid cards have mismatched widths: '
                '${rects.map((r) => r.width).toList()}',
          );
        });
      }
    }
  }

  for (final size in <Size>[
    const Size(360, 640),
    const Size(393, 852),
    const Size(412, 915),
    const Size(800, 1200),
  ]) {
    testWidgets('grid uses the space above Emergency at $size', (tester) async {
      await pumpDashboard(tester, size, AppLanguage.english, false);
      final cards = find.byType(DashboardFeatureCard);
      final lowerCard = tester.getRect(cards.at(2));
      final emergency = tester.getRect(find.byType(EmergencyCard));
      final firstCard = tester.getRect(cards.first);
      final firstIcon = tester.getRect(find.descendant(
        of: cards.first, matching: find.byIcon(Icons.description_rounded),
      ));
      expect(firstIcon.center.dx, closeTo(firstCard.center.dx, 1));
      expect(emergency.top - lowerCard.bottom, closeTo(16, 1));
      expect(emergency.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('card rows grow with available phone height', (tester) async {
    await pumpDashboard(tester, const Size(393, 852), AppLanguage.english, false);
    final mediumHeight = tester.getRect(find.byType(DashboardFeatureCard).first).height;
    await pumpDashboard(tester, const Size(412, 915), AppLanguage.english, false);
    final tallHeight = tester.getRect(find.byType(DashboardFeatureCard).first).height;
    expect(tallHeight, greaterThan(mediumHeight + 20));
  });
}
