import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/app_controller.dart';
import 'package:saathi_app/src/data/test_login.dart';
import 'package:saathi_app/src/l10n/app_text.dart';
import 'package:saathi_app/src/screens/linking_screens.dart';
import 'package:saathi_app/src/theme.dart';

/// Covers the manual linking screen and the temporary test credential.
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget harness(AppController controller) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        theme: buildSaathiTheme(),
        locale: controller.language.locale,
        localizationsDelegates: const [
          AppText.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppText.supportedLocales,
        home: ManualLinkScreen(controller: controller),
      ),
    );
  }

  testWidgets('shows an error when the activation code is empty', (
    tester,
  ) async {
    final controller = AppController();
    await tester.pumpWidget(harness(controller));

    await tester.enterText(find.byType(TextFormField).at(0), kTestPatientUid);
    await tester.enterText(find.byType(TextFormField).at(2), 'Patient Device');
    await tester.enterText(find.byType(TextFormField).at(2), '');

    await tester.ensureVisible(find.text('Link this phone'));
    await tester.tap(find.text('Link this phone'));
    await tester.pumpAndSettle();

    expect(find.text('Enter activation code'), findsOneWidget);
    expect(controller.status, isNot(AppStatus.patientLinked));
  });

  testWidgets('test credentials link the device without any backend call', (
    tester,
  ) async {
    final controller = AppController();
    await tester.pumpWidget(harness(controller));

    await tester.enterText(find.byType(TextFormField).at(0), kTestPatientUid);
    await tester.enterText(find.byType(TextFormField).at(2), 'Patient Device');
    await tester.enterText(
      find.byType(TextFormField).at(3),
      kTestActivationCode,
    );

    await tester.ensureVisible(find.text('Link this phone'));
    await tester.tap(find.text('Link this phone'));
    await tester.pumpAndSettle();

    expect(controller.status, AppStatus.patientLinked);
    expect(controller.patient?.name, 'Test Patient');
  });

  testWidgets('test QR payload links the device without any backend call', (
    tester,
  ) async {
    final controller = AppController();
    await controller.linkWithQr(kTestQrPayload);

    expect(controller.status, AppStatus.patientLinked);
    expect(controller.patient?.uid, kTestPatientUid);
  });

  testWidgets('a stored test token restores the session on next launch', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'patient_device_token': kTestDeviceToken,
      'patient_id': '1',
    });

    final controller = AppController();
    await controller.initialize();

    expect(controller.status, AppStatus.patientLinked);
    expect(controller.patient?.uid, kTestPatientUid);
  });
}
