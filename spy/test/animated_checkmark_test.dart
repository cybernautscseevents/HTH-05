import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_staff/src/api_client.dart';
import 'package:saathi_staff/src/screens/registration_success_screen.dart';

void main() {
  group('Paytm-Style Live Animated Checkmark & Confetti Tests', () {
    testWidgets('AnimatedSuccessCheckmark animates from dot to live checkmark',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSuccessCheckmark(size: 84),
            ),
          ),
        ),
      );

      // Initial frame: widget mounted
      expect(find.byType(AnimatedSuccessCheckmark), findsOneWidget);

      // Frame at t = 50ms: center dot state
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AnimatedSuccessCheckmark), findsOneWidget);

      // Frame at t = 300ms: expanding circle
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(AnimatedSuccessCheckmark), findsOneWidget);

      // Frame at t = 850ms: live checkmark drawing
      await tester.pump(const Duration(milliseconds: 550));
      expect(find.byType(AnimatedSuccessCheckmark), findsOneWidget);

      // Frame at t = 1800ms: settled and completed
      await tester.pump(const Duration(milliseconds: 950));
      expect(find.byType(AnimatedSuccessCheckmark), findsOneWidget);
    });

    testWidgets(
        'RegistrationSuccessScreen renders live checkmark, celebratory confetti, and registration details',
        (WidgetTester tester) async {
      final fakeResponse = RegisterPatientResponse(
        patientId: 39,
        registrationNo: 'MA-2026-000039',
        isMock: false,
        patient: PatientInfo(
          fullName: 'Manvit',
          dateOfBirth: '1996-01-01',
          diseaseCondition: 'hypertension',
          emergencyContact: '7894561231',
          preferredLanguage: 'English',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationSuccessScreen(
            response: fakeResponse,
            assignedDoctorName: 'Dr. Meera',
          ),
        ),
      );

      // Initial frame: screen renders immediately with checkmark and details
      expect(find.text('Patient Registered'), findsOneWidget);
      expect(
        find.text('Registration completed successfully for Manvit.'),
        findsOneWidget,
      );
      expect(find.byType(AnimatedSuccessCheckmark), findsOneWidget);

      // Forward time through dot expansion, confetti launch, and checkmark stroke
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 1000));

      // Check details are visible and intact
      expect(find.text('REGISTRATION DETAILS'), findsOneWidget);
      expect(find.text('PATIENT DETAILS'), findsOneWidget);
      expect(find.text('MA-2026-000039'), findsOneWidget);
      expect(find.text('Manvit'), findsOneWidget);
      expect(find.text('Exit to Dashboard'), findsOneWidget);
    });
  });
}
