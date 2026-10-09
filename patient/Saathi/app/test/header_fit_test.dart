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

/// The dashboard header keeps its logo-only treatment while ensuring the
/// language pill and menu button are visible at every supported text scale.
///
/// Measured against a *real* typeface, not the test framework's default —
/// see the note on dashboard_one_screen_test.dart for why that distinction
/// matters here specifically: the wordmark-fit decision is a width
/// comparison, and the test framework's font draws every glyph as a full em
/// square, which would make a comfortably-fitting string look like it
/// doesn't fit.
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

  Future<void> pump(
    WidgetTester tester,
    double width,
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

    tester.view.physicalSize = Size(width, 800) * 3;
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
  }

  // 360dp is the narrowest width the dashboard officially supports (see
  // dashboard_one_screen_test.dart); this is the tightest budget the header
  // has to work within.
  const width = 360.0;

  for (final language in AppLanguage.values) {
    for (final scale in [1.0, 1.15, 1.3, 1.5, 2.0]) {
      testWidgets('${language.code} @${scale}x: logo-only header controls '
          'are never clipped', (tester) async {
        await pump(tester, width, scale, language);
        expect(tester.takeException(), isNull);

        // The centered emblem carries a compact brand label below it.
        expect(find.text('Saathi Patient App'), findsOneWidget);

        // The menu button and the language pill are both on screen, fully
        // within the viewport, with a real (non-zero) size.
        final moreRect = tester.getRect(find.byIcon(Icons.menu_rounded));
        expect(moreRect.left, greaterThanOrEqualTo(0));
        expect(moreRect.right, lessThanOrEqualTo(width));
        expect(moreRect.width, greaterThan(0));

        final pillRect = tester.getRect(find.byIcon(Icons.translate_rounded));
        expect(pillRect.left, greaterThanOrEqualTo(0));
        expect(pillRect.right, lessThanOrEqualTo(width));
        expect(pillRect.width, greaterThan(0));
      });
    }
  }
}
