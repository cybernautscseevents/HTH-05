import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_staff/src/api_client.dart';

void main() {
  test('deployed/demo API defaults to the Saathi Render backend', () {
    expect(ApiClient().baseUrl, 'https://saathi-api-v2-x5at.onrender.com');
  });

  test('custom API_URL supports local development and trims trailing slashes', () {
    expect(
      ApiClient(baseUrl: 'http://10.0.2.2:8000///').baseUrl,
      'http://10.0.2.2:8000',
    );
  });
}
