import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/l10n/app_text.dart';
import 'package:saathi_app/src/services/reminder_service.dart';
import 'package:saathi_app/src/theme.dart';
import 'package:saathi_app/src/widgets/listen_button.dart';

/// A patient who presses Listen has no way today to silence it again short
/// of waiting the sentence out. [ListenButton] fixes that by turning itself
/// into a Stop control for as long as the shared TTS engine is speaking —
/// whichever button started it.
///
/// [ReminderService.instance.isSpeaking] is driven directly here rather than
/// through [ReminderService.speak]/[speakSentence]: those call into
/// `flutter_tts`'s platform channel, which does not exist in a widget-test
/// environment. Flipping the same notifier the real TTS start/completion/
/// cancel handlers flip is what the button actually listens to, so this
/// still exercises the real toggle logic.
void main() {
  Widget harness(VoidCallback onPressed) => MaterialApp(
    theme: buildSaathiTheme(),
    localizationsDelegates: const [
      AppText.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppText.supportedLocales,
    home: Scaffold(
      body: ListenButton.speaker(
        label: 'Listen',
        semanticLabel: 'Listen to this screen',
        onPressed: onPressed,
      ),
    ),
  );

  tearDown(() {
    // Every test leaves the shared singleton in the state it started in.
    ReminderService.instance.isSpeaking.value = false;
  });

  testWidgets('shows Listen and the speaker icon while idle', (tester) async {
    await tester.pumpWidget(harness(() {}));

    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
  });

  testWidgets('turns into Stop the moment the engine starts speaking', (
    tester,
  ) async {
    await tester.pumpWidget(harness(() {}));

    ReminderService.instance.isSpeaking.value = true;
    await tester.pump();

    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Listen'), findsNothing);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
  });

  testWidgets('tapping it while speaking stops the engine instead of '
      'starting it again', (tester) async {
    var startPresses = 0;
    await tester.pumpWidget(harness(() => startPresses++));

    ReminderService.instance.isSpeaking.value = true;
    await tester.pump();

    await tester.tap(find.byType(ListenButton));
    await tester.pump();

    // The button's own onPressed (which would start a fresh sentence) was
    // not the thing invoked — stopping was.
    expect(startPresses, 0);
    expect(ReminderService.instance.isSpeaking.value, isFalse);

    await tester.pump();
    expect(find.text('Listen'), findsOneWidget);
  });

  testWidgets('tapping it while idle calls the caller\'s onPressed', (
    tester,
  ) async {
    var startPresses = 0;
    await tester.pumpWidget(harness(() => startPresses++));

    await tester.tap(find.byType(ListenButton));
    await tester.pump();

    expect(startPresses, 1);
  });
}
