import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/l10n/app_text.dart';
import 'package:saathi_app/src/screens/medicine_reminder_screen.dart';
import 'package:saathi_app/src/services/reminder_service.dart';
import 'package:saathi_app/src/theme.dart';

/// Verifies the medicine reminder screen visually reinforces the three
/// pieces of information the brief calls out — patient name, medicine name,
/// local disease name — without going through [ReminderService], which
/// would hit platform channels (notifications, TTS) that don't exist in a
/// widget-test environment.
void main() {
  const content = ReminderContent(
    patientName: 'Lakshmi Iyer',
    medicineName: 'Metformin 500mg',
    instruction: '1 tablet, after food',
    diseaseName: 'Sugar illness (diabetes)',
    language: AppLanguage.english,
  );

  Future<void> pumpReminder(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: buildSaathiTheme(),
      localizationsDelegates: const [
        AppText.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppText.supportedLocales,
      home: const MedicineReminderScreen(content: content),
    ),
  );

  testWidgets('shows patient name, medicine name, and local disease name', (
    tester,
  ) async {
    await pumpReminder(tester);

    expect(find.text('Lakshmi Iyer'), findsOneWidget);
    expect(find.text('Metformin 500mg'), findsOneWidget);
    expect(find.textContaining('Sugar illness (diabetes)'), findsOneWidget);
  });

  testWidgets(
    'an unscheduled preview cannot falsely confirm a recorded dose',
    (tester) async {
      await pumpReminder(tester);

      expect(find.text('I HAVE TAKEN IT'), findsOneWidget);
      await tester.ensureVisible(find.text('I HAVE TAKEN IT'));
      await tester.tap(find.text('I HAVE TAKEN IT'));
      await tester.pumpAndSettle();

      expect(find.text('Well done. Noted.'), findsNothing);
      expect(find.text('I HAVE TAKEN IT'), findsOneWidget);
      expect(find.textContaining('no saved schedule'), findsOneWidget);
    },
  );
}
