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
import 'package:saathi_app/src/widgets/saathi_bottom_navigation.dart';

/// Light and dark must lay the dashboard out identically. Only colour,
/// gradient and shadow may differ between them.
///
/// This is not a stylistic preference. The two modes had already drifted:
/// twelve separate sizes — the hero card's padding and minimum height, the
/// calendar badge, the forward arrow, both card discs, the logo, the wordmark,
/// the nav's icon, indicator and padding — were each written as
/// `isDark ? bigger : smaller`. Dark was roughly 47px taller overall, so a
/// spacing change made against one mode silently did nothing for the other,
/// and the one-screen guarantee was only ever measured in light.
///
/// Every dashboard metric now lives as a single constant in theme.dart. This
/// test is what keeps it that way: it compares real laid-out geometry, so a
/// reintroduced `isDark ? a : b` around any size fails here.
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
    Size size,
    double scale,
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

  /// The geometry of everything that defines the screen's spacing.
  Map<String, Rect> geometry(WidgetTester tester) {
    final result = <String, Rect>{};
    void record(String name, Finder finder) {
      final found = finder.evaluate();
      for (var i = 0; i < found.length; i++) {
        result['$name[$i]'] = tester.getRect(finder.at(i));
      }
    }

    record('appointment', find.byType(AppointmentCard));
    record('feature', find.byType(DashboardFeatureCard));
    record('emergency', find.byType(EmergencyCard));
    record('nav', find.byType(SaathiBottomNavigation));
    return result;
  }

  const sizes = <String, Size>{
    '360x800': Size(360, 800),
    '393x852': Size(393, 852),
    '412x915': Size(412, 915),
  };

  for (final entry in sizes.entries) {
    for (final language in AppLanguage.values) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('light and dark lay out identically — ${entry.key} '
            '${language.code} @${scale}x', (tester) async {
          addTearDown(tester.view.reset);

          await pump(tester, entry.value, scale, language, false);
          final light = geometry(tester);

          await pump(tester, entry.value, scale, language, true);
          final dark = geometry(tester);

          expect(
            dark.keys.toSet(),
            light.keys.toSet(),
            reason: 'the two themes rendered a different set of cards',
          );
          for (final key in light.keys) {
            expect(
              dark[key],
              light[key],
              reason:
                  '$key is laid out differently in dark mode. Sizing must '
                  'come from the shared constants in theme.dart, not from '
                  'an isDark branch — only colour may differ.',
            );
          }
        });
      }
    }
  }
}
