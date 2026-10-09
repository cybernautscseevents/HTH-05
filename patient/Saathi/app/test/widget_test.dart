import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/app_controller.dart';
import 'package:saathi_app/src/l10n/app_text.dart';
import 'package:saathi_app/src/screens/app_shell.dart';
import 'package:saathi_app/src/theme.dart';

void main() {
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget harness(AppController controller, {VoidCallback? onLogin}) {
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
        home: PatientWelcomeScreen(
          controller: controller,
          onLogin: onLogin ?? () {},
        ),
      ),
    );
  }

  testWidgets('welcome screen shows only the approved final content', (
    tester,
  ) async {
    final controller = AppController(storage: const FlutterSecureStorage());
    await tester.pumpWidget(harness(controller));

    expect(
      find.text(
        'Your hospital staff will link this phone to your health record once.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ask staff to activate'), findsOneWidget);
    expect(find.text('One-time hospital login'), findsOneWidget);
    expect(
      find.text('Next step: staff will open the QR code scanner.'),
      findsOneWidget,
    );

    // The benefit row, reassurance banner and footer chips were removed in
    // the final design — this guards against them creeping back.
    expect(find.text('Safe'), findsNothing);
    expect(find.text('Staff help'), findsNothing);
    expect(find.text('Better care'), findsNothing);
    expect(find.text('Staff will do everything.'), findsNothing);
    expect(find.text('Quick setup'), findsNothing);

    // No staff sign-in affordance — this app is patient-only.
    expect(find.text('Hospital staff sign in'), findsNothing);
  });

  testWidgets('offers exactly English, Hindi and Kannada', (tester) async {
    final controller = AppController(storage: const FlutterSecureStorage());
    await tester.pumpWidget(harness(controller));

    await tester.ensureVisible(find.text('English'));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('ಕನ್ನಡ'), findsOneWidget);
    expect(find.text('मराठी'), findsNothing);
    expect(find.text('தமிழ்'), findsNothing);
  });

  testWidgets('welcome screen translates fully into Kannada', (tester) async {
    final controller = AppController(storage: const FlutterSecureStorage());
    await tester.pumpWidget(harness(controller));

    await tester.ensureVisible(find.text('English'));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ಕನ್ನಡ'));
    await tester.pumpAndSettle();

    // Heading, body and button all switch to Kannada.
    expect(find.text('ಒಮ್ಮೆ ಮಾತ್ರ ಆಸ್ಪತ್ರೆ ಲಾಗಿನ್'), findsOneWidget);
    expect(find.text('ಸಿಬ್ಬಂದಿಗೆ ಚಾಲನೆ ಮಾಡಲು ಹೇಳಿ'), findsOneWidget);
    expect(
      find.text(
        'ಆಸ್ಪತ್ರೆ ಸಿಬ್ಬಂದಿ ಈ ಫೋನ್ ಅನ್ನು ನಿಮ್ಮ ಆರೋಗ್ಯ ದಾಖಲೆಗೆ ಒಮ್ಮೆ ಜೋಡಿಸುತ್ತಾರೆ.',
      ),
      findsOneWidget,
    );
    expect(find.text('One-time hospital login'), findsNothing);
  });

  testWidgets('welcome screen translates into Hindi', (tester) async {
    final controller = AppController(storage: const FlutterSecureStorage());
    await tester.pumpWidget(harness(controller));

    await tester.ensureVisible(find.text('English'));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(find.text('एक बार का अस्पताल लॉगिन'), findsOneWidget);
    expect(find.text('स्टाफ़ से चालू करवाएँ'), findsOneWidget);
    expect(find.text('One-time hospital login'), findsNothing);
  });

  testWidgets('activate button triggers the existing linking flow', (
    tester,
  ) async {
    var tapped = false;
    final controller = AppController(storage: const FlutterSecureStorage());
    await tester.pumpWidget(harness(controller, onLogin: () => tapped = true));

    await tester.ensureVisible(find.text('Ask staff to activate'));
    await tester.tap(find.text('Ask staff to activate'));
    expect(tapped, isTrue);
  });

  testWidgets('welcome screen does not overflow at 2x system font scale', (
    tester,
  ) async {
    final controller = AppController(storage: const FlutterSecureStorage());
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: harness(controller),
      ),
    );
    await tester.pumpAndSettle();

    // A RenderFlex overflow would have been recorded as an exception.
    expect(tester.takeException(), isNull);
    expect(find.text('Ask staff to activate'), findsOneWidget);
  });
}
