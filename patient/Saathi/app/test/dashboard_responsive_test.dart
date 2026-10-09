import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/app_controller.dart';
import 'package:saathi_app/src/l10n/app_text.dart';
import 'package:saathi_app/src/models.dart';
import 'package:saathi_app/src/screens/patient_dashboard_screen.dart';
import 'package:saathi_app/src/theme.dart';

/// Sweeps the dashboard across every screen size, system font scale and
/// language combination this app is expected to run in, and fails on any
/// overflow.
///
/// The audience for this app skews elderly, which means large system font
/// settings are the norm rather than an edge case, and cheap small-screen
/// Android phones are common. A layout that only works at 1x on a modern
/// handset would be broken for a large share of real users, so this is a
/// first-class test rather than a nicety.
void main() {
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  const sizes = <String, Size>{
    'tiny 320x568': Size(320, 568),
    'small 360x640': Size(360, 640),
    'normal 393x852': Size(393, 852),
    'large 430x932': Size(430, 932),
  };
  const scales = [1.0, 1.3, 1.6, 2.0, 2.5];

  for (final language in AppLanguage.values) {
    for (final entry in sizes.entries) {
      for (final scale in scales) {
        testWidgets('${language.code} ${entry.key} @${scale}x', (tester) async {
          final controller = AppController(
            storage: const FlutterSecureStorage(),
          );
          controller.patient = const Patient(
            id: 1,
            uid: 'SAA-2608-A1B2C3',
            name: 'Lakshmi Iyer',
            age: 63,
            condition: 'Type 2 Diabetes Mellitus',
          );
          controller.status = AppStatus.patientLinked;
          controller.language = language;

          tester.view.physicalSize = entry.value * 3;
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              theme: buildSaathiTheme(),
              locale: language.locale,
              supportedLocales: AppText.supportedLocales,
              localizationsDelegates: const [
                AppText.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: PatientDashboardScreen(controller: controller),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // The whole page must be reachable by scrolling, not clipped.
          final scrollable = find.byType(Scrollable).first;
          await tester.drag(scrollable, const Offset(0, -4000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
