// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:saathi_staff/src/auth_provider.dart';
import 'package:saathi_staff/main.dart';

void main() {
  testWidgets('Role select screen smoke test', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(useMockApi: true),
        child: const SaathiStaffApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify that role select screen elements are present.
    expect(find.text('Saathi'), findsOneWidget);
    expect(find.text('STAFF PORTAL'), findsOneWidget);
    expect(find.text('Hospital Staff'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
  });
}
