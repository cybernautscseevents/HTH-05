import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:saathi_staff/src/auth_provider.dart';
import 'package:saathi_staff/src/screens/admin_staff_management_screen.dart';

Widget createTestWidget(Widget child) {
  final authProvider = AuthProvider(useMockApi: true);
  return MaterialApp(
    home: ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('Add Staff Dialog Form Focus-Loss Validation UX Tests', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(const StaffAccountsView()));
    await tester.pumpAndSettle();

    // Open Add Staff Dialog
    final addButton = find.widgetWithText(FilledButton, 'Add Staff Member');
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Save Staff Member');
    expect(saveButton, findsOneWidget);

    // 1. Initial State -> No validation errors visible on any field
    expect(find.text('Full name is required'), findsNothing);
    expect(find.text('Username is required'), findsNothing);
    expect(find.text('Password is required'), findsNothing);
    expect(find.text('Phone number is required'), findsNothing);
    expect(find.text('Email address is required'), findsNothing);
    expect(find.text('Enter exactly 10 digits for Indian phone number'), findsNothing);
    expect(find.text('Enter a valid email address'), findsNothing);

    // Save button must be disabled when form is incomplete/invalid
    final saveWidgetInitial = tester.widget<FilledButton>(saveButton);
    expect(saveWidgetInitial.onPressed, isNull, reason: 'Save button must be disabled on empty form');

    final nameField = find.byType(TextFormField).at(0);
    final usernameField = find.byType(TextFormField).at(1);
    final passwordField = find.byType(TextFormField).at(2);
    final phoneField = find.byType(TextFormField).at(5);
    final emailField = find.byType(TextFormField).at(6);

    // 2. Phone = 9 while typing -> No error yet
    await tester.enterText(phoneField, '9');
    await tester.pump();
    expect(find.text('Enter exactly 10 digits for Indian phone number'), findsNothing, reason: 'No error while actively typing in field');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull, reason: 'Save disabled while form invalid');

    // User leaves Phone field (taps Username field) -> Error appears
    await tester.tap(usernameField);
    await tester.pumpAndSettle();
    expect(find.text('Enter exactly 10 digits for Indian phone number'), findsOneWidget, reason: 'Error appears on focus loss/leaving field');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    // Phone = 9876543210 -> Valid, error clears
    await tester.enterText(phoneField, '9876543210');
    await tester.tap(usernameField);
    await tester.pumpAndSettle();
    expect(find.text('Enter exactly 10 digits for Indian phone number'), findsNothing);

    // 3. Email = abc while typing -> No error yet
    await tester.enterText(emailField, 'abc');
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsNothing, reason: 'No error while actively typing in email field');

    // User leaves Email field -> Error appears
    await tester.tap(passwordField);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget, reason: 'Error appears on leaving email field');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    // Email = abc@gmail.com -> Valid, error clears
    await tester.enterText(emailField, 'abc@gmail.com');
    await tester.tap(passwordField);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsNothing);

    // 4. Password = 123 while typing -> No error yet
    await tester.enterText(passwordField, '123');
    await tester.pump();
    expect(find.text('Password must be at least 8 characters'), findsNothing, reason: 'No error while actively typing in password field');

    // User leaves Password field -> Error appears
    await tester.tap(nameField);
    await tester.pumpAndSettle();
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    // Password = Password123 -> Valid
    await tester.enterText(passwordField, 'Password123');
    await tester.tap(nameField);
    await tester.pumpAndSettle();
    expect(find.text('Password must be at least 8 characters'), findsNothing);

    // 5. Fill remaining fields validly (Name & Username)
    await tester.enterText(nameField, 'Dr. Smith');
    await tester.enterText(usernameField, 'doctor_01');
    await tester.tap(emailField);
    await tester.pumpAndSettle();

    // All fields valid -> Save button ENABLED
    final saveWidgetFinal = tester.widget<FilledButton>(saveButton);
    expect(saveWidgetFinal.onPressed, isNotNull, reason: 'Save button enabled when all fields valid');
  });
}
