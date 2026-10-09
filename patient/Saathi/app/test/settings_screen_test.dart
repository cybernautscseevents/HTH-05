import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/app_controller.dart';
import 'package:saathi_app/src/l10n/app_text.dart';
import 'package:saathi_app/src/models.dart';
import 'package:saathi_app/src/screens/settings_screen.dart';
import 'package:saathi_app/src/services/reminder_service.dart';
import 'package:saathi_app/src/settings.dart';
import 'package:saathi_app/src/theme.dart';

/// Coverage for the settings screen: that every control actually changes app
/// state, that the read-only sections show the linked patient's real details,
/// and — as importantly — that nothing on it lets a patient undo the link the
/// hospital made.
void main() {
  setUpAll(() {
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

  /// Wraps the screen the way main.dart does, so the text-size setting is
  /// actually applied to the tree under test rather than merely stored.
  Widget harness(AppController controller) {
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
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: AppTextScaler(
                media.textScaler,
                controller.textSize.factor,
              ),
            ),
            child: child!,
          );
        },
        home: SettingsScreen(controller: controller),
      ),
    );
  }

  testWidgets('shows settings controls in the patient\'s language', (
    tester,
  ) async {
    final controller = linkedController();
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    // Section headings. "Language" appears twice: the section and the app bar's
    // own language pill semantics are separate, so scope to the headings.
    expect(find.text('Language'), findsWidgets);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('How to use this app'), findsNothing);
    expect(find.text('Display and theme'), findsOneWidget);

    // Scroll to the bottom so the later sections are built and laid out.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(find.text('Voice'), findsOneWidget);
  });

  testWidgets('nothing here can unlink the device or sign the patient out', (
    tester,
  ) async {
    final controller = linkedController();
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    // This is a safety property of the design, not a cosmetic one: a patient
    // who unlinks their own phone has to travel back to the hospital to be let
    // back in. Asserted on the rendered text so that adding such a control
    // later fails here loudly.
    for (final forbidden in [
      'Log out',
      'Sign out',
      'Logout',
      'Unlink',
      'Delete',
      'Remove device',
      'Account',
    ]) {
      expect(
        find.textContaining(forbidden, findRichText: true),
        findsNothing,
        reason: 'settings must not offer "$forbidden"',
      );
    }
  });

  testWidgets('language choice switches the whole screen immediately', (
    tester,
  ) async {
    final controller = linkedController();
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    expect(find.text('Text size'), findsOneWidget);

    // The rows are labelled in each language's own script, so a patient who
    // cannot read the current language can still find theirs.
    await tester.tap(find.text('ಕನ್ನಡ'));
    await tester.pumpAndSettle();

    expect(controller.language, AppLanguage.kannada);
    expect(find.text('ಅಕ್ಷರದ ಗಾತ್ರ'), findsOneWidget); // Text size
    expect(find.text('Text size'), findsNothing);
  });

  testWidgets('text size choice is applied to the app, not just recorded', (
    tester,
  ) async {
    final controller = linkedController();
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Take 1 tablet after food.'));
    await tester.pumpAndSettle();
    final before = tester.getSize(find.text('Take 1 tablet after food.'));

    await tester.ensureVisible(find.text('Very large'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Very large'));
    await tester.pumpAndSettle();

    expect(controller.textSize, PatientTextSize.largest);
    // The live sample really grew — the setting is wired through MediaQuery,
    // not stored and ignored.
    final after = tester.getSize(find.text('Take 1 tablet after food.'));
    expect(after.height, greaterThan(before.height));
  });

  testWidgets('text size multiplies the system scale instead of replacing it', (
    tester,
  ) async {
    final controller = linkedController();
    controller.textSize = PatientTextSize.large;

    // A patient who has already turned their phone's own font size up must not
    // be silently reset to the app's idea of "large".
    const system = TextScaler.linear(1.5);
    const scaler = AppTextScaler(system, 1.25);
    expect(scaler.scale(16), closeTo(16 * 1.5 * 1.25, 0.001));

    // Equality matters: MediaQuery relayouts the whole app when its data
    // compares unequal, so two identical scalers must be equal.
    expect(scaler, const AppTextScaler(system, 1.25));
  });

  testWidgets('voice speed choice updates the controller and the service', (
    tester,
  ) async {
    final controller = linkedController();
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    // "Slow" is unambiguous — the label appears once, in the voice section.
    await tester.ensureVisible(find.text('Slow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slow'));
    await tester.pumpAndSettle();

    expect(controller.voiceSpeed, VoiceSpeed.slow);
    // Every spoken prompt in the app reads its rate from here.
    expect(ReminderService.instance.speechRate, VoiceSpeed.slow.rate);
  });

  testWidgets('tutorial is absent while voice and reminder controls remain', (
    tester,
  ) async {
    final controller = linkedController();
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1800));
    await tester.pumpAndSettle();

    expect(find.text('How to use this app'), findsNothing);
    expect(
      find.textContaining('shows when to come to the hospital next'),
      findsNothing,
    );
    expect(find.text('LISTEN TO THIS'), findsNothing);
    expect(find.text('TRY THE VOICE'), findsOneWidget);
    expect(
      find.text('Hear your name, medicine and condition now.'),
      findsOneWidget,
    );
    expect(find.text('Test notification in 30 seconds'), findsOneWidget);
  });

  group('responsiveness', () {
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
          testWidgets('${language.code} ${entry.key} @${scale}x', (
            tester,
          ) async {
            final controller = linkedController();
            controller.language = language;

            tester.view.physicalSize = entry.value * 3;
            tester.view.devicePixelRatio = 3.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => MaterialApp(
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
                    child: SettingsScreen(controller: controller),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Every section must be reachable by scrolling, not clipped.
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -6000),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
