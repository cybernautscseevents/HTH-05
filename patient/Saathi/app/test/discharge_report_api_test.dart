import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saathi_app/src/api_client.dart';
import 'package:saathi_app/src/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final status in [401, 403, 404, 422, 500, 503]) {
    test(
      'save preserves HTTP $status even when Render returns non-JSON',
      () async {
        final api = ApiClient(
          client: MockClient(
            (request) async => http.Response('Internal server error', status),
          ),
        );
        await expectLater(
          api.saveDischargeReport(token: 'fictional-token', report: {}),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'status',
              status,
            ),
          ),
        );
      },
    );
  }
  test(
    'save submits reviewed payload with bearer token and preserves backend detail',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/patients/me/discharge-reports');
          expect(request.method, 'POST');
          expect(request.headers['Authorization'], 'Bearer fictional-token');
          expect(jsonDecode(request.body)['summary'], 'Fictional summary');
          return http.Response(
            jsonEncode({'detail': 'Report storage is unavailable.'}),
            503,
          );
        }),
      );
      await expectLater(
        api.saveDischargeReport(
          token: 'fictional-token',
          report: {'summary': 'Fictional summary'},
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Report storage is unavailable.',
          ),
        ),
      );
    },
  );
  test(
    'save rejects a missing confirmation or another patient response',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'patient_device_token': 'fictional-token',
        'patient_id': '1',
      });
      for (final response in [
        {'report_id': 7},
        {'report_id': 7, 'patient_id': 2},
      ]) {
        final controller = AppController(
          api: ApiClient(
            client: MockClient(
              (request) async => http.Response(jsonEncode(response), 201),
            ),
          ),
        );
        await expectLater(
          controller.saveDischargeReport({
            'extracted': {},
            'source': {
              'type': 'application/pdf',
              'document_reference': 'a' * 64,
            },
            'extracted_text': 'Fictional source',
            'summary': 'Fictional summary',
          }, 'fictional.pdf'),
          throwsA(isA<ApiException>()),
        );
        expect(controller.savedDischargeReports, isEmpty);
        controller.dispose();
      }
    },
  );
}
