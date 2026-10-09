import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/api_client.dart';

void main() {
  test('deployed/demo API defaults to the Saathi Render backend', () {
    expect(
      ApiClient.baseUrl,
      'https://saathi-api-v2-x5at.onrender.com',
    );
  });

  test('API base URL normalization prevents duplicate endpoint slashes', () {
    expect(
      normalizeApiBaseUrl(' https://example.test/// '),
      'https://example.test',
    );
  });
}
