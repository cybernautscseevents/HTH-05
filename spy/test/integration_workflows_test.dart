import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:saathi_staff/src/auth_provider.dart';
import 'package:saathi_staff/src/api_client.dart';
import 'package:saathi_staff/src/notification_provider.dart';
import 'package:saathi_staff/src/screens/staff_shell.dart';
import 'package:saathi_staff/src/screens/patient_profile_screen.dart';
import 'package:saathi_staff/src/screens/registration_success_screen.dart';
import 'package:saathi_staff/src/screens/doctor_patient_profile_screen.dart';

Widget createTestApp(AuthProvider auth, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<NotificationProvider>(
        create: (_) => NotificationProvider(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('FLOW 1: Dashboard -> Patient Profile -> Back', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const StaffShell()));
    // Pump delays for dashboard statistics & recent patients
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Quick Operations'), findsOneWidget);
    expect(find.text('Recent Patients'), findsOneWidget);

    // Tap the first recent patient (Rajesh Gupta)
    final recentPatientFinder = find.text('Rajesh Gupta');
    expect(recentPatientFinder, findsOneWidget);
    await tester.tap(recentPatientFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify PatientProfileScreen is shown
    expect(find.text('Patient Profile'), findsOneWidget);
    expect(find.byTooltip('Back to Patients'), findsOneWidget);
    expect(find.text('Rajesh Gupta'), findsWidgets);

    // Tap Back to Patients
    await tester.tap(find.byTooltip('Back to Patients'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify back on Dashboard
    expect(find.text('Quick Operations'), findsOneWidget);
  });

  testWidgets('FLOW 2: Dashboard -> Search Patients -> Profile', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const StaffShell()));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Tap "Search Patients" in Quick Operations
    await tester.tap(find.text('Search Patients'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify on Patients tab
    expect(find.text('Patients'), findsWidgets);
    // SearchPatientsScreen loads the registered-patient list immediately;
    // its empty-search state is therefore the results heading, not the
    // pre-load "Find a patient" placeholder.
    expect(find.textContaining('All Registered Patients'), findsOneWidget);

    // Enter search query "Rahul"
    await tester.enterText(find.byType(TextField), 'Rahul');
    await tester.tap(find.text('Search'));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Rahul Verma'), findsOneWidget);

    // Tap patient card
    await tester.tap(find.text('Rahul Verma'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify profile is displayed
    expect(find.text('Rahul Verma'), findsWidgets);
    expect(find.text('Type 2 Diabetes'), findsWidgets);
  });

  testWidgets(
    'FLOW 3 & 4: Patient Profile -> Manage Devices -> Active State -> Revoke',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = AuthProvider(useMockApi: true);
      await tester.runAsync(() async {
        await auth.signIn('reception', 'pass', 'Hospital Staff');
      });

      final rahul = PatientSearchResult(
        patientId: 1,
        registrationNo: 'MA-2026-000001',
        name: 'Rahul Verma',
        dateOfBirth: '1985-03-15',
        diseaseCondition: 'Type 2 Diabetes',
        preferredLanguage: 'Hindi',
      );

      await tester.pumpWidget(
        createTestApp(auth, PatientProfileScreen(patient: rahul)),
      );
      await tester.pump();

      // Tap Manage Devices
      await tester.ensureVisible(find.text('Manage Devices'));
      await tester.tap(find.text('Manage Devices'));
      await tester.pump();
      // Device loading delays (listPatientDevices: 500ms, getPatientActivation: 300ms)
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      // Verify Rahul is automatically selected on the pushed screen and Active device appears
      expect(find.text('Rahul Verma'), findsWidgets);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text("Rahul's Phone (Redmi Note 12)"), findsOneWidget);
      expect(find.text('Revoke Device'), findsOneWidget);

      // Tap Revoke Device
      await tester.tap(find.text('Revoke Device'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify confirmation dialog
      expect(find.text('Revoke Device Access'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap confirm Revoke in dialog
      final confirmButton = find.widgetWithText(FilledButton, 'Revoke Device');
      await tester.tap(confirmButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Verify state updated to Pending Activation
      expect(find.text('Pending Activation'), findsWidgets);
      expect(
        find.text('This patient has not linked a Saathi device yet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('FLOW 5: Registration Success -> View Patient -> Device State', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    late final RegisterPatientResponse regResponse;
    await tester.runAsync(() async {
      regResponse = await auth.mockApiClient.registerPatient(
        name: 'Test Flow Patient',
        dateOfBirth: '1990-05-10',
        diseaseCondition: 'Asthma',
        emergencyContact: '9876543210',
      );
    });

    await tester.pumpWidget(
      createTestApp(auth, RegistrationSuccessScreen(response: regResponse)),
    );
    await tester.pump();

    expect(find.text('Patient Registered'), findsOneWidget);
    expect(find.text('View Patient'), findsOneWidget);
    expect(find.text('Register Another'), findsOneWidget);

    // Ensure View Patient button is visible and tap it
    await tester.ensureVisible(find.text('View Patient'));
    await tester.tap(find.text('View Patient'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Patient Profile opened
    // The profile presents the patient's name in both the page header and
    // the identity card, so verify both visible representations remain.
    expect(find.text('Test Flow Patient'), findsNWidgets(2));
    expect(find.text('10 May 1990'), findsOneWidget);
    expect(find.text('Asthma'), findsWidgets);
  });

  testWidgets(
    'FLOW 8: Doctor Portal Dashboard -> Clinical Profile -> Tabs -> Report Dialog',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = AuthProvider(useMockApi: true);
      await tester.runAsync(() async {
        await auth.signIn('doctor', 'pass', 'Doctor');
      });

      final rahul = PatientSearchResult(
        patientId: 1,
        registrationNo: 'MA-2026-000001',
        name: 'Rahul Verma',
        dateOfBirth: '1985-03-15',
        diseaseCondition: 'Type 2 Diabetes',
        preferredLanguage: 'Hindi',
      );

      await tester.pumpWidget(
        createTestApp(auth, DoctorPatientProfileScreen(patient: rahul)),
      );
      // Wait for clinical data loading
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Clinical Profile'), findsOneWidget);
      expect(find.text('Rahul Verma'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Medical History'), findsOneWidget);
      expect(find.text('Visits'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);

      // Switch to Medical History Tab
      await tester.tap(find.text('Medical History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Routine follow-up'), findsOneWidget);

      // Switch to Visits Tab
      await tester.tap(find.text('Visits'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Routine consultation'), findsOneWidget);

      // Switch to Reports Tab
      await tester.tap(find.text('Reports'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Blood Test Panel'), findsOneWidget);

      // Tap View Report
      final viewButton = find.widgetWithText(OutlinedButton, 'View').first;
      await tester.tap(viewButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Demo Report Dialog
      expect(
        find.text(
          'Demo Report — This report is a demonstration record for the Saathi prototype.',
        ),
        findsOneWidget,
      );
      expect(find.text('Close'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  testWidgets('FLOW 6: Admin Login & Isolation', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('admin', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const StaffShell()));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Admin should see Staff Accounts tab in sidebar
    expect(find.text('Staff Accounts'), findsOneWidget);

    // Tap Staff Accounts
    await tester.tap(find.text('Staff Accounts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hospital Staff Accounts'), findsOneWidget);
  });

  testWidgets('FLOW 7: Sign Out Confirmation Dialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const StaffShell()));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Find logout button in sidebar
    final logoutButton = find.byTooltip('Sign Out');
    expect(logoutButton, findsOneWidget);
    await tester.tap(logoutButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Sign Out alert dialog
    expect(
      find.text(
        'Are you sure you want to sign out of the Saathi Staff Portal?',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
  });
}
