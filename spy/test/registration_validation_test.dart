import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:saathi_staff/src/auth_provider.dart';
import 'package:saathi_staff/src/screens/receptionist_home_screen.dart';
import 'package:saathi_staff/src/screens/registration_success_screen.dart';

Widget createTestApp(AuthProvider auth, Widget child) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('1. Initial State -> No validation errors displayed on any field', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const RegisterPatientView()));
    await tester.pump();

    // Verify required field labels with asterisks
    expect(find.text('Full Name *'), findsOneWidget);
    expect(find.text('Date of Birth *'), findsOneWidget);
    expect(find.text('Emergency Contact Number *'), findsOneWidget);
    expect(find.text('Disease / Condition *'), findsOneWidget);

    // Initial state: NO validation error text should be present anywhere
    expect(find.text('Patient name is required'), findsNothing);
    expect(find.text('Date of birth is required'), findsNothing);
    expect(find.text('Emergency contact number is required'), findsNothing);
    expect(find.text('Disease / condition is required'), findsNothing);
  });

  testWidgets('2. Typing "a" in Full Name -> No errors on untouched fields', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const RegisterPatientView()));
    await tester.pump();

    // User types "a" into Full Name
    await tester.enterText(find.byType(TextFormField).at(0), 'a');
    await tester.pump();

    // Full Name is valid ("a" is not empty)
    expect(find.text('Patient name is required'), findsNothing);

    // Untouched fields must NOT show validation errors
    expect(find.text('Date of birth is required'), findsNothing);
    expect(find.text('Emergency contact number is required'), findsNothing);
    expect(find.text('Disease / condition is required'), findsNothing);
  });

  testWidgets('3. Submit with all fields empty -> registration blocked and all errors shown', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const RegisterPatientView()));
    await tester.pump();

    int initialCount = 0;
    await tester.runAsync(() async {
      final list = await auth.mockApiClient.searchPatients('');
      initialCount = list.length;
    });

    // Tap Register Patient with empty fields
    await tester.tap(find.widgetWithText(FilledButton, 'Register Patient'));
    await tester.pump();

    // Check all 4 inline errors are displayed simultaneously
    expect(find.text('Patient name is required'), findsOneWidget);
    expect(find.text('Date of birth is required'), findsOneWidget);
    expect(find.text('Emergency contact number is required'), findsOneWidget);
    expect(find.text('Disease / condition is required'), findsOneWidget);

    // Verify zero API calls dispatched
    await tester.runAsync(() async {
      final list = await auth.mockApiClient.searchPatients('');
      expect(list.length, initialCount);
    });
    expect(find.byType(RegistrationSuccessScreen), findsNothing);
  });

  testWidgets('4. Fill Full Name only and submit -> only missing fields show errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const RegisterPatientView()));
    await tester.pump();

    // Enter name only
    await tester.enterText(find.byType(TextFormField).at(0), 'Rajesh Kumar');
    await tester.tap(find.widgetWithText(FilledButton, 'Register Patient'));
    await tester.pump();

    // Name has no error
    expect(find.text('Patient name is required'), findsNothing);

    // Only missing fields show errors
    expect(find.text('Date of birth is required'), findsOneWidget);
    expect(find.text('Emergency contact number is required'), findsOneWidget);
    expect(find.text('Disease / condition is required'), findsOneWidget);
    expect(find.byType(RegistrationSuccessScreen), findsNothing);
  });

  testWidgets('5. Sequential correction of fields -> each error clears immediately when valid', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const RegisterPatientView()));
    await tester.pump();

    // Trigger validation on all fields
    await tester.tap(find.widgetWithText(FilledButton, 'Register Patient'));
    await tester.pump();

    expect(find.text('Patient name is required'), findsOneWidget);
    expect(find.text('Date of birth is required'), findsOneWidget);
    expect(find.text('Emergency contact number is required'), findsOneWidget);
    expect(find.text('Disease / condition is required'), findsOneWidget);

    // Correct Name -> Name error clears
    await tester.enterText(find.byType(TextFormField).at(0), 'Rajesh Kumar');
    await tester.pump();
    expect(find.text('Patient name is required'), findsNothing);
    expect(find.text('Date of birth is required'), findsOneWidget);
    expect(find.text('Emergency contact number is required'), findsOneWidget);
    expect(find.text('Disease / condition is required'), findsOneWidget);

    // Correct DOB -> DOB error clears
    await tester.enterText(find.byType(TextFormField).at(1), '1988-12-14');
    await tester.pump();
    expect(find.text('Date of birth is required'), findsNothing);
    expect(find.text('Emergency contact number is required'), findsOneWidget);
    expect(find.text('Disease / condition is required'), findsOneWidget);

    // Correct Emergency Contact -> Emergency Contact error clears
    await tester.enterText(find.byType(TextFormField).at(2), '+91 9876543210');
    await tester.pump();
    expect(find.text('Emergency contact number is required'), findsNothing);
    expect(find.text('Disease / condition is required'), findsOneWidget);

    // Correct Disease -> Disease error clears
    await tester.enterText(find.byType(TextFormField).at(3), 'Hypertension');
    await tester.pump();
    expect(find.text('Disease / condition is required'), findsNothing);

    // Now submit -> registration succeeds
    await tester.tap(find.widgetWithText(FilledButton, 'Register Patient'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(RegistrationSuccessScreen), findsOneWidget);
    expect(find.text('Patient Registered'), findsOneWidget);
    expect(find.textContaining('Rajesh Kumar'), findsWidgets);
  });

  testWidgets('6. Invalid phone format -> phone error appears on interaction', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const RegisterPatientView()));
    await tester.pump();

    // Type invalid phone containing letters
    await tester.enterText(find.byType(TextFormField).at(2), '1234abcd');
    await tester.pump();

    expect(find.text('Please enter a valid phone number'), findsOneWidget);

    // Other untouched fields should NOT show errors
    expect(find.text('Patient name is required'), findsNothing);
    expect(find.text('Date of birth is required'), findsNothing);
    expect(find.text('Disease / condition is required'), findsNothing);
  });

  testWidgets('7. Future DOB -> future date error appears on interaction', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const RegisterPatientView()));
    await tester.pump();

    final futureDate = '${DateTime.now().year + 1}-01-01';
    await tester.enterText(find.byType(TextFormField).at(1), futureDate);
    await tester.pump();

    expect(find.text('Date of birth cannot be in the future'), findsOneWidget);

    // Other untouched fields should NOT show errors
    expect(find.text('Patient name is required'), findsNothing);
    expect(find.text('Emergency contact number is required'), findsNothing);
    expect(find.text('Disease / condition is required'), findsNothing);
  });

  testWidgets('8. Whitespace-only fields -> registration blocked', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const RegisterPatientView()));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), '   ');
    await tester.enterText(find.byType(TextFormField).at(1), '1995-08-20');
    await tester.enterText(find.byType(TextFormField).at(2), '   ');
    await tester.enterText(find.byType(TextFormField).at(3), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Register Patient'));
    await tester.pump();

    expect(find.text('Patient name is required'), findsOneWidget);
    expect(find.text('Emergency contact number is required'), findsOneWidget);
    expect(find.text('Disease / condition is required'), findsOneWidget);
    expect(find.byType(RegistrationSuccessScreen), findsNothing);
  });

  testWidgets('9. All required fields valid -> registration opens its success page', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = AuthProvider(useMockApi: true);
    await tester.runAsync(() async {
      await auth.signIn('reception', 'pass', 'Hospital Staff');
    });

    await tester.pumpWidget(createTestApp(auth, const RegisterPatientView()));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'Kavita Patel');
    await tester.enterText(find.byType(TextFormField).at(1), '1992-04-18');
    await tester.enterText(find.byType(TextFormField).at(2), '+91 9876543210');
    await tester.enterText(find.byType(TextFormField).at(3), 'Thyroid Disorder');

    await tester.tap(find.widgetWithText(FilledButton, 'Register Patient'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(RegistrationSuccessScreen), findsOneWidget);
    expect(find.text('Patient Registered'), findsOneWidget);
    expect(find.textContaining('Kavita Patel'), findsWidgets);
    expect(find.text('Register Another'), findsOneWidget);
    expect(find.text('View Patient'), findsOneWidget);
  });
}
