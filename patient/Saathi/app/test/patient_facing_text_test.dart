import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/utils/patient_facing_text.dart';

void main() {
  test('cleans Markdown, bullets, links and duplicate source footer', () {
    final clean = cleanPatientFacingText(
      '**Paracetamol 500 mg**\n\n- Take [as written](https://example.test)\n'
      'Source: demo.pdf',
    );
    expect(clean, 'Paracetamol 500 mg\n\n• Take as written');
    expect(clean, isNot(contains('**')));
    expect(clean, isNot(contains('Source:')));
  });

  test('speech text excludes source labels and Markdown markers', () {
    expect(
      cleanPatientFacingText(
        '**Take 1 tablet** by mouth.\nSource: demo.pdf',
        forSpeech: true,
      ),
      'Take 1 tablet by mouth.',
    );
  });

  test('long report filename is shortened with extension intact', () {
    final label = conciseReportSource(
      'very_long_synthetic_discharge_report_filename_for_patient.pdf',
      maxLength: 30,
    );
    expect(label.length, lessThanOrEqualTo(30));
    expect(label, endsWith('… .pdf'.replaceAll(' ', '')));
  });
}
