import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/api_client.dart';
import 'package:saathi_app/src/app_controller.dart';
import 'package:saathi_app/src/l10n/app_text.dart';
import 'package:saathi_app/src/models.dart';
import 'package:saathi_app/src/screens/ask_saathi_sheet.dart';
import 'package:saathi_app/src/screens/patient_dashboard_screen.dart';
import 'package:saathi_app/src/theme.dart';
import 'package:saathi_app/src/widgets/dashboard_cards.dart';
import 'package:saathi_app/src/widgets/draggable_listen_ball.dart';

class _FakeReportApi extends ApiClient {
  final questions = <String>[];
  final languages = <String>[];
  bool hasReport = true;
  bool longReview = false;
  bool failSave = false;
  bool failRefresh = false;
  int saves = 0;
  Completer<void>? saveGate;

  @override
  Future<List<Map<String, dynamic>>> getDischargeReports(String token) async {
    if (failRefresh && hasReport) {
      throw const ApiException('Refresh unavailable', statusCode: 503);
    }
    return hasReport
        ? [
            {
              'report_id': 7,
              'patient_id': 1,
              'hospital_name': 'Sample General Hospital',
              'original_filename': 'fictional.pdf',
            },
          ]
        : [];
  }

  @override
  Future<Map<String, dynamic>> summarizeDischargeDocument({
    required String token,
    required String fileName,
    required List<int> bytes,
  }) async => {
    'summary': longReview
        ? List.filled(45, 'Fictional source-grounded report summary.').join(' ')
        : 'Fictional report summary.',
    'extracted': {
      'diagnosis': 'Seasonal allergic rhinitis',
      'hospital': 'Sample General Hospital',
      'medicines': [],
      if (longReview)
        'unclear_details': List.generate(
          24,
          (index) =>
              'Source detail $index: not documented in the fictional report.',
        ),
    },
    'source': {
      'type': 'application/pdf',
      'document_reference': 'fictional-hash',
    },
    'extracted_text': 'Fictional report text for a UI test.',
  };

  @override
  Future<Map<String, dynamic>> saveDischargeReport({
    required String token,
    required Map<String, dynamic> report,
  }) async {
    saves++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) {
      throw const ApiException(
        'Report storage is unavailable.',
        statusCode: 503,
      );
    }
    hasReport = true;
    return {
      ...report,
      'report_id': 7,
      'patient_id': 1,
      'hospital_name': 'Sample General Hospital',
    };
  }

  @override
  Future<Map<String, dynamic>> askDischargeQuestion({
    required String token,
    required int reportId,
    required String question,
    required String language,
  }) async {
    questions.add(question);
    languages.add(language);
    return {
      'answer':
          '**The report says the review is not booked.**\nSource: fictional.pdf',
      'source': {
        'filename': 'fictional.pdf',
        'hospital': 'Sample General Hospital',
      },
    };
  }
}

void main() {
  const channel = MethodChannel('saathi/discharge_document');

  AppController dashboardController() {
    FlutterSecureStorage.setMockInitialValues({});
    final controller = AppController(storage: const FlutterSecureStorage());
    controller.patient = const Patient(
      id: 1,
      uid: 'DEMO-1',
      name: 'Aarav',
      age: 28,
      condition: 'Seasonal Allergic Rhinitis',
    );
    controller.status = AppStatus.patientLinked;
    return controller;
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    final controller = dashboardController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaathiTheme(),
        home: PatientDashboardScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Ask Saathi opens over dashboard and closes with X', (
    tester,
  ) async {
    await pumpDashboard(tester);
    await tester.tap(find.byKey(const Key('askSaathiDraft')));
    await tester.pumpAndSettle();
    expect(find.byType(AskSaathiSheet), findsOneWidget);
    expect(
      find.text("Hi, I'm Saathi. How can I help you today?"),
      findsOneWidget,
    );
    expect(find.text('Add Document'), findsOneWidget);
    expect(find.text('Capture Document'), findsOneWidget);
    expect(find.byType(EmergencyCard), findsOneWidget);
    await tester.tap(find.byKey(const Key('askSaathiClose')));
    await tester.pumpAndSettle();
    expect(find.byType(AskSaathiSheet), findsNothing);
    expect(find.byType(DraggableListenBall), findsOneWidget);
  });

  testWidgets('Android back closes the chat sheet', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.byKey(const Key('askSaathiDraft')));
    await tester.pumpAndSettle();
    expect(find.byType(AskSaathiSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AskSaathiSheet), findsNothing);
    expect(find.byType(EmergencyCard), findsOneWidget);
  });

  testWidgets('plus popup offers picker and camera actions', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await pumpDashboard(tester);
    await tester.tap(find.byKey(const Key('askSaathiPlus')));
    await tester.pumpAndSettle();
    expect(find.text('Add Document'), findsOneWidget);
    expect(find.text('Capture Document'), findsOneWidget);
    await tester.tap(find.text('Add Document'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('askSaathiPlus')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capture Document'));
    await tester.pumpAndSettle();
    expect(calls, ['pickDocument', 'captureDocument']);
  });

  testWidgets('camera failure is visible above the chat sheet', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(
        code: 'camera_unavailable',
        message: 'Unable to open the camera on this device',
      ),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await pumpDashboard(tester);
    await tester.tap(find.byKey(const Key('askSaathiDraft')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capture Document'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Unable to open the camera on this device'),
      findsOneWidget,
    );
  });

  testWidgets('bar draft opens chat and send explains missing report', (
    tester,
  ) async {
    await pumpDashboard(tester);
    await tester.enterText(find.byKey(const Key('askSaathiDraft')), 'My dose?');
    await tester.tap(find.byKey(const Key('askSaathiBarSend')));
    await tester.pumpAndSettle();
    expect(find.byType(AskSaathiSheet), findsOneWidget);
    expect(find.text('My dose?'), findsWidgets);
    expect(
      find.textContaining('add a document or select a saved report'),
      findsOneWidget,
    );
  });

  testWidgets(
    'selected report sends via existing authenticated chat contract',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'patient_device_token': 'widget-token',
        'patient_id': '1',
      });
      final api = _FakeReportApi();
      final controller = AppController(
        api: api,
        storage: const FlutterSecureStorage(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaathiTheme(),
          home: Scaffold(
            body: AskSaathiSheet(
              controller: controller,
              initialDraft: 'Is my review booked?',
              submitInitial: true,
              initialReportId: 7,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.questions, ['Is my review booked?']);
      expect(api.languages, ['English']);
      expect(find.textContaining('not booked'), findsOneWidget);
      expect(
        find.textContaining('Source: Sample General Hospital'),
        findsOneWidget,
      );
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('Source: fictional.pdf'), findsNothing);
      controller.language = AppLanguage.kannada;
      await tester.enterText(
        find.byKey(const Key('askSaathiComposer')),
        'ಮುಂದಿನ ಭೇಟಿ ಯಾವಾಗ?',
      );
      await tester.tap(find.byKey(const Key('askSaathiSend')));
      await tester.pumpAndSettle();
      expect(api.languages, ['English', 'Kannada']);
    },
  );

  testWidgets('saving a picked report returns to the same chat sheet', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'patient_device_token': 'widget-token',
      'patient_id': '1',
    });
    final api = _FakeReportApi()..hasReport = false;
    final controller = AppController(
      api: api,
      storage: const FlutterSecureStorage(),
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'name': 'fictional.pdf',
        'bytes': Uint8List.fromList([37, 80, 68, 70]),
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaathiTheme(),
        home: Scaffold(body: AskSaathiSheet(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Document'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your discharge summary'), findsOneWidget);
    await tester.tap(find.text('Save report'));
    await tester.pumpAndSettle();
    expect(find.byType(AskSaathiSheet), findsOneWidget);
    expect(find.byKey(const Key('askSaathiReportSelector')), findsOneWidget);
    expect(find.text('Sample General Hospital'), findsOneWidget);
  });

  testWidgets('long discharge review scrolls while Save stays fixed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({
      'patient_device_token': 'widget-token',
      'patient_id': '1',
    });
    final api = _FakeReportApi()..longReview = true;
    final controller = AppController(
      api: api,
      storage: const FlutterSecureStorage(),
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'name': 'fictional.pdf',
        'bytes': Uint8List.fromList([37, 80, 68, 70]),
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaathiTheme(),
        home: Scaffold(body: AskSaathiSheet(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Document'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('dischargeSummaryContent')), findsOneWidget);
    final save = find.byKey(const Key('saveDischargeReport'));
    expect(save, findsOneWidget);
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(640));
    await tester.drag(
      find.byKey(const Key('dischargeSummaryContent')),
      const Offset(0, -500),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Source detail 23'), findsOneWidget);
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(640));
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.byType(AskSaathiSheet), findsOneWidget);
  });

  testWidgets(
    'save shows progress, prevents repeat taps, retains errors and retries into chat',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'patient_device_token': 'widget-token',
        'patient_id': '1',
      });
      final api = _FakeReportApi()
        ..hasReport = false
        ..failSave = true
        ..saveGate = Completer<void>();
      final controller = AppController(
        api: api,
        storage: const FlutterSecureStorage(),
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'name': 'fictional.pdf',
          'bytes': Uint8List.fromList([37, 80, 68, 70]),
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSaathiTheme(),
          home: Scaffold(body: AskSaathiSheet(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Document'));
      // The sheet deliberately stays in its uploading state until review closes.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final button = find.byKey(const Key('saveDischargeReport'));
      await tester.tap(button);
      await tester.pump();
      expect(find.text('Saving report...'), findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(api.saves, 1);
      api.saveGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('dischargeReportSaveError')), findsOneWidget);
      expect(find.text('Report storage is unavailable.'), findsOneWidget);
      expect(find.text('Fictional report summary.'), findsOneWidget);
      expect(find.text('Report saved successfully'), findsNothing);
      api.failSave = false;
      api.failRefresh = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Your discharge summary'), findsNothing);
      expect(find.byKey(const Key('askSaathiReportSelector')), findsOneWidget);
      expect(find.text('Report saved successfully'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('askSaathiComposer')),
        'What is my dose?',
      );
      await tester.tap(find.byKey(const Key('askSaathiSend')));
      await tester.pumpAndSettle();
      expect(api.questions, ['What is my dose?']);
      expect(api.saves, 2);
    },
  );

  testWidgets('keyboard inset keeps the sheet composer visible', (
    tester,
  ) async {
    await pumpDashboard(tester);
    await tester.tap(find.byKey(const Key('askSaathiDraft')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final composer = tester.getRect(find.byKey(const Key('askSaathiComposer')));
    final keyboardTop =
        tester.view.physicalSize.height / tester.view.devicePixelRatio -
        MediaQuery.viewInsetsOf(
          tester.element(find.byType(AskSaathiSheet)),
        ).bottom;
    expect(composer.bottom, lessThan(keyboardTop));
    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(360, 640),
    const Size(393, 852),
    const Size(412, 915),
    const Size(800, 1200),
  ]) {
    testWidgets('empty chat is compact and grows for messages at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpDashboard(tester);
      await tester.tap(find.byKey(const Key('askSaathiDraft')));
      await tester.pumpAndSettle();
      final surface = find.byKey(const Key('askSaathiSheetSurface'));
      final emptyHeight = tester.getRect(surface).height;
      expect(emptyHeight, lessThan(size.height * .74));
      expect(find.byKey(const Key('askSaathiComposer')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('askSaathiComposer')),
        'What does my report say?',
      );
      await tester.tap(find.byKey(const Key('askSaathiSend')));
      await tester.pumpAndSettle();
      expect(tester.getRect(surface).height, greaterThan(emptyHeight));
      expect(find.text('What does my report say?'), findsOneWidget);
      expect(
        find.textContaining('add a document or select a saved report'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('small phone chat remains usable with 2x text and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final controller = dashboardController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSaathiTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PatientDashboardScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('askSaathiDraft')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Capture Document'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(AskSaathiSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Capture Document'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 750);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final composer = tester.getRect(find.byKey(const Key('askSaathiComposer')));
    expect(composer.bottom, lessThan(640 - 250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('speaker floats outside Emergency and four cards remain', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(find.byType(DraggableListenBall), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EmergencyCard),
        matching: find.byType(DraggableListenBall),
      ),
      findsNothing,
    );
    expect(find.text('My Prescription'), findsOneWidget);
    expect(find.text('Medicines'), findsOneWidget);
    expect(find.text('Appointments'), findsOneWidget);
    expect(find.text('Health Summary'), findsOneWidget);
    expect(find.text('EMERGENCY'), findsOneWidget);
    expect(
      tester.getRect(find.byType(DraggableListenBall)).right,
      lessThanOrEqualTo(
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      ),
    );
  });
}
