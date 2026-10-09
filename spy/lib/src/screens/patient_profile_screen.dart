import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../api_client.dart';
import '../auth_provider.dart';
import '../theme.dart';
import 'manage_devices_screen.dart';

class PatientProfileScreen extends StatelessWidget {
  final PatientSearchResult patient;
  final bool openAdmissionOnLoad;

  const PatientProfileScreen({
    super.key,
    required this.patient,
    this.openAdmissionOnLoad = false,
  });

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) {
      return 'Not specified';
    }

    try {
      final date = DateTime.parse(rawDate.trim());

      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      return '${date.day} '
          '${months[date.month - 1]} '
          '${date.year}';
    } catch (_) {
      return rawDate;
    }
  }

  Future<void> _deletePatient(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Patient'),

          content: Text('Are you sure you want to delete ${patient.name}?'),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: saathiEmergency),

              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },

              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (!authProvider.useMockApi) {
        final token = authProvider.token;

        if (token == null) {
          throw ApiException('Session expired. Please login again.');
        }

        await authProvider.apiClient.deletePatient(
          patient.patientId,
          token: token,
        );
      }

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${patient.name} deleted successfully.'),
          backgroundColor: saathiGreen,
        ),
      );

      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: saathiEmergency),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete patient: $e'),
          backgroundColor: saathiEmergency,
        ),
      );
    }
  }

  void _returnToPatients(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    final isAdmin = authProvider.role?.toLowerCase() == 'admin';

    return Scaffold(
      backgroundColor: saathiCream,

      // APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,

        elevation: 0,

        automaticallyImplyLeading: false,

        leading: IconButton(
          tooltip: 'Back to Patients',
          icon: const Icon(Icons.arrow_back, color: saathiNavy),
          onPressed: () => _returnToPatients(context),
        ),

        title: const Text(
          'Patient Profile',

          style: TextStyle(color: saathiNavy, fontWeight: FontWeight.bold),
        ),

        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 16),

              child: OutlinedButton.icon(
                onPressed: () {
                  _deletePatient(context);
                },

                icon: const Icon(Icons.delete_outline, color: saathiEmergency),

                label: const Text(
                  'Delete Patient',
                  style: TextStyle(color: saathiEmergency),
                ),
              ),
            ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // PATIENT CARD
            Card(
              color: Colors.white,

              elevation: 0,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: saathiLine),
              ),

              child: Padding(
                padding: const EdgeInsets.all(24),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    CircleAvatar(
                      radius: 32,

                      backgroundColor: saathiGreen.withValues(alpha: 0.12),

                      child: Text(
                        patient.name.isNotEmpty
                            ? patient.name[0].toUpperCase()
                            : 'P',

                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: saathiGreen,
                        ),
                      ),
                    ),

                    const SizedBox(width: 20),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            patient.name,

                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: saathiNavy,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'Registration No: ${patient.registrationNo}',

                            style: const TextStyle(
                              fontSize: 14,
                              color: saathiBodyGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          if (patient.diseaseCondition != null &&
                              patient.diseaseCondition!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),

                            Text(
                              'Condition: ${patient.diseaseCondition}',

                              style: const TextStyle(
                                fontSize: 14,
                                color: saathiBodyGrey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // INFORMATION TITLE
            const Text(
              'Patient Information',

              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: saathiNavy,
              ),
            ),

            const SizedBox(height: 12),

            // INFORMATION CARD
            Card(
              color: Colors.white,

              elevation: 0,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: saathiLine),
              ),

              child: Padding(
                padding: const EdgeInsets.all(24),

                child: Column(
                  children: [
                    _infoRow(
                      icon: Icons.calendar_today,
                      label: 'Date of Birth',
                      value: _formatDate(patient.dateOfBirth),
                    ),

                    const Divider(height: 28),

                    _infoRow(
                      icon: Icons.language,
                      label: 'Preferred Language',
                      value: patient.preferredLanguage.isNotEmpty
                          ? patient.preferredLanguage
                          : 'English',
                    ),

                    if (patient.diseaseCondition != null &&
                        patient.diseaseCondition!.trim().isNotEmpty) ...[
                      const Divider(height: 28),

                      _infoRow(
                        icon: Icons.medical_services,
                        label: 'Primary Condition',
                        value: patient.diseaseCondition!,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            _AdmissionAndDischargePanel(
              patient: patient,
              openAdmissionOnLoad: openAdmissionOnLoad,
            ),

            const SizedBox(height: 24),

            // DEVICE TITLE
            const Text(
              'Saathi Device',

              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: saathiNavy,
              ),
            ),

            const SizedBox(height: 12),

            // DEVICE CARD
            Card(
              color: Colors.white,

              elevation: 0,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: saathiLine),
              ),

              child: Padding(
                padding: const EdgeInsets.all(24),

                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Saathi Device',

                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: saathiNavy,
                            ),
                          ),

                          SizedBox(height: 6),

                          Text(
                            'Device management can be accessed from the Devices section.',

                            style: TextStyle(
                              fontSize: 13,
                              color: saathiBodyGrey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 20),

                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              backgroundColor: saathiCream,
                              body: SafeArea(
                                child: ManageDevicesScreen(
                                  initialPatient: patient,
                                ),
                              ),
                            ),
                          ),
                        );
                      },

                      icon: const Icon(Icons.devices),

                      label: const Text('Manage Devices'),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: saathiTeal,
                        elevation: 0,
                        side: const BorderSide(color: saathiTeal),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Container(
          padding: const EdgeInsets.all(9),

          decoration: BoxDecoration(
            color: saathiCream,
            borderRadius: BorderRadius.circular(8),
          ),

          child: Icon(icon, size: 20, color: saathiNavy),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                label,

                style: const TextStyle(
                  fontSize: 12,
                  color: saathiBodyGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                value,

                style: const TextStyle(
                  fontSize: 15,
                  color: saathiInk,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdmissionAndDischargePanel extends StatefulWidget {
  const _AdmissionAndDischargePanel({
    required this.patient,
    this.openAdmissionOnLoad = false,
  });

  final PatientSearchResult patient;
  final bool openAdmissionOnLoad;

  @override
  State<_AdmissionAndDischargePanel> createState() =>
      _AdmissionAndDischargePanelState();
}

class _AdmissionAndDischargePanelState
    extends State<_AdmissionAndDischargePanel> {
  bool _loading = true;
  bool _saving = false;
  bool _doctorAdmitted = false;
  int? _eligibleVisitId;
  Map<String, dynamic>? _existingAdmission;
  Map<String, dynamic>? _dischargeSummary;
  String? _error;
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (auth.useMockApi || token == null) {
      setState(() {
        _loading = false;
        _error =
            'Admission services require a connection to the hospital server.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await auth.apiClient.getAdmissionOptions(
        widget.patient.patientId,
        token: token,
      );
      Map<String, dynamic>? summary;
      try {
        summary = await auth.apiClient.getDischargeSummary(
          widget.patient.patientId,
          token: token,
        );
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
      if (!mounted) return;
      setState(() {
        _doctorAdmitted = options['doctor_admitted'] == true;
        _eligibleVisitId = options['visit_id'] as int?;
        _existingAdmission =
            options['existing_admission'] as Map<String, dynamic>?;
        _dischargeSummary = summary;
        _loading = false;
      });
      if (widget.openAdmissionOnLoad &&
          !_autoOpened &&
          _doctorAdmitted &&
          _existingAdmission == null) {
        _autoOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAdmissionForm();
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.statusCode != 404) _error = e.message;
        _dischargeSummary = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load admission and discharge status.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admission',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: saathiNavy,
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admit patient',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: saathiNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _existingAdmission != null
                          ? 'Admitted to ${_existingAdmission!['ward_type']} ward · ${_existingAdmission!['bed_number']}'
                          : _doctorAdmitted
                          ? 'Doctor marked this patient for admission.'
                          : 'Available after the doctor submits a consultation marked Admitted.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: saathiBodyGrey,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: saathiEmergency,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (_loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_existingAdmission != null)
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check),
                  label: const Text('Admitted'),
                  style: FilledButton.styleFrom(
                    backgroundColor: saathiGreen,
                    disabledBackgroundColor: saathiGreen,
                    disabledForegroundColor: Colors.white,
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _doctorAdmitted && !_saving
                      ? _showAdmissionForm
                      : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.local_hospital_outlined),
                  label: Text(_doctorAdmitted ? 'Admit' : 'Waiting for doctor'),
                  style: FilledButton.styleFrom(
                    backgroundColor: saathiGreen,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: saathiBodyGrey,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Discharge',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: saathiNavy,
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discharge summary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: saathiNavy,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'View or download after the doctor submits a finalized discharge report.',
                      style: TextStyle(fontSize: 13, color: saathiBodyGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _dischargeSummary == null || _loading
                    ? null
                    : _viewSummary,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _dischargeSummary == null || _loading
                    ? null
                    : _downloadSummary,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download'),
                style: FilledButton.styleFrom(
                  backgroundColor: _dischargeSummary == null
                      ? Colors.grey.shade300
                      : saathiGreen,
                  disabledForegroundColor: saathiBodyGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel({required Widget child}) => Card(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: saathiLine),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );

  Future<void> _showAdmissionForm() async {
    if (_eligibleVisitId == null) return;
    final ward = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose a ward'),
        content: const Text(
          'Choose a ward to admit the patient and assign a bed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'general'),
            icon: const Icon(Icons.king_bed_outlined),
            label: const Text('General ward'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'special'),
            icon: const Icon(Icons.local_hospital_outlined),
            label: const Text('Special ward'),
          ),
        ],
      ),
    );
    if (ward == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      if (token == null) {
        throw ApiException('Session expired. Please sign in again.');
      }
      await auth.apiClient.createPatientAdmission(
        widget.patient.patientId,
        visitId: _eligibleVisitId!,
        wardType: ward,
        token: token,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient admitted and a bed was assigned.'),
            backgroundColor: saathiGreen,
          ),
        );
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: saathiEmergency),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _viewSummary() {
    final summary = _dischargeSummary;
    if (summary == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discharge summary'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(_summaryText(summary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadSummary() async {
    final summary = _dischargeSummary;
    if (summary == null) return;
    final sections = _summarySections(summary);
    final medicationRows = _dischargeMedicationRows(summary);
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        maxPages: 2,
        margin: const pw.EdgeInsets.fromLTRB(48, 46, 48, 42),
        theme: pw.ThemeData.withFont(
          base: pw.Font.times(),
          bold: pw.Font.timesBold(),
          italic: pw.Font.timesItalic(),
          boldItalic: pw.Font.timesBoldItalic(),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: pdf.PdfColors.grey),
          ),
        ),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'Discharge Summary: General Format',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 26),
          for (final field in _summaryFields(summary))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '${field['title']}: ',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.TextSpan(
                      text: _pdfSafe(field['content']!),
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          pw.SizedBox(height: 14),
          for (final section in sections)
            pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(bottom: 15),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _pdfSafe(section['title']!),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (section['title'] == 'DISCHARGE MEDICATIONS')
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: pdf.PdfColors.black,
                        width: 0.6,
                      ),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(3),
                        1: pw.FlexColumnWidth(2),
                        2: pw.FlexColumnWidth(3),
                      },
                      children: [
                        pw.TableRow(
                          children: [
                            _certificateCell('Medicine', bold: true),
                            _certificateCell('Course', bold: true),
                            _certificateCell('Instruction', bold: true),
                          ],
                        ),
                        for (final row in medicationRows)
                          pw.TableRow(
                            children: [
                              _certificateCell(row['medicine']!),
                              _certificateCell(row['course']!),
                              _certificateCell(row['instruction']!),
                            ],
                          ),
                      ],
                    )
                  else
                    pw.Text(
                      _pdfSafe(section['content']!),
                      style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    await Printing.layoutPdf(
      name: 'discharge-summary-${widget.patient.registrationNo}.pdf',
      onLayout: (format) => document.save(),
    );
  }

  List<Map<String, String>> _summarySections(Map<String, dynamic> summary) {
    final sections = <Map<String, String>>[];
    final seen = <String>{};

    void add(String title, dynamic raw) {
      final value = raw?.toString().trim() ?? '';
      if (value.isEmpty) return;
      final key = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (!seen.add(key)) return;
      sections.add({'title': title, 'content': value});
    }

    final admissionDiagnosis = summary['admission_diagnosis']
        ?.toString()
        .trim();
    final finalDiagnosis = summary['final_diagnosis']?.toString().trim();
    if (admissionDiagnosis?.isNotEmpty == true &&
        finalDiagnosis?.isNotEmpty == true &&
        admissionDiagnosis!.toLowerCase() == finalDiagnosis!.toLowerCase()) {
      add('ADMISSION AND FINAL DIAGNOSIS', finalDiagnosis);
    } else {
      add('ADMISSION DIAGNOSIS', admissionDiagnosis);
      add('FINAL DIAGNOSIS', finalDiagnosis);
    }

    add(
      'TREATMENT IN HOSPITAL / HOSPITAL COURSE (RECORDED CONSULTATION NOTES)',
      summary['consultation_notes'],
    );
    add('DISCHARGE PLAN & ADVICE', summary['clinical_notes']);
    final condition = summary['discharge_condition'];
    if (condition is Map && condition.isNotEmpty) {
      add(
        'CONDITION UPON DISCHARGE - RECORDED VITALS',
        condition.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n'),
      );
    }
    final medications = _dischargeMedicationRows(summary);
    add(
      'DISCHARGE MEDICATIONS',
      medications
          .map(
            (row) =>
                '${row['medicine']} | ${row['course']} | ${row['instruction']}',
          )
          .join('\n'),
    );

    final appointments =
        (summary['follow_up_appointments'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) {
              final appointment = raw.cast<String, dynamic>();
              final parts = <String>[];
              final date = _formatCertificateDate(appointment['date']);
              if (date != null) parts.add(date);
              for (final key in ['physician', 'reason']) {
                final value = appointment[key]?.toString().trim() ?? '';
                if (value.isNotEmpty) parts.add(value);
              }
              return parts.join(' - ');
            })
            .where((line) => line.isNotEmpty)
            .toList();
    add('FOLLOW-UP APPOINTMENTS', appointments.join('\n'));
    return sections;
  }

  List<Map<String, String>> _dischargeMedicationRows(
    Map<String, dynamic> summary,
  ) {
    final rows = <Map<String, String>>[];
    final seen = <String>{};
    for (final raw in (summary['medications'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final med = raw.cast<String, dynamic>();
      final name = med['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final course = <String>[];
      for (final key in ['strength', 'dosage', 'route', 'frequency']) {
        final value = med[key]?.toString().trim() ?? '';
        if (value.isNotEmpty && !course.any((item) => _sameText(item, value))) {
          course.add(value);
        }
      }
      final days = med['duration_days'];
      if (days != null) course.add('$days days');

      final instructions = <String>[];
      for (final key in ['instructions', 'food_timing']) {
        final value = med[key]?.toString().trim() ?? '';
        if (value.isNotEmpty &&
            !instructions.any((item) => _sameText(item, value)) &&
            !instructions.any(
              (item) => item.toLowerCase().contains(value.toLowerCase()),
            )) {
          instructions.add(value);
        }
      }
      final row = <String, String>{
        'medicine': name,
        'course': course.join('; '),
        'instruction': instructions.join('; '),
      };
      final key = row.values
          .map(
            (value) =>
                value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim(),
          )
          .join('|');
      if (seen.add(key)) rows.add(row);
    }
    return rows;
  }

  bool _sameText(String first, String second) =>
      first.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim() ==
      second.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  pw.Widget _certificateCell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      _pdfSafe(text),
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  String _pdfSafe(String value) => value
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('·', '-')
      .replaceAll('×', 'x')
      .replaceAll('°', ' degrees')
      .replaceAll(RegExp(r'[^\x20-\x7E\n]'), ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();

  List<Map<String, String>> _summaryFields(Map<String, dynamic> summary) {
    final fields = <Map<String, String>>[];
    final seen = <String>{};
    void add(String title, dynamic raw) {
      final value = raw?.toString().trim() ?? '';
      final key = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (value.isNotEmpty && seen.add(key)) {
        fields.add({'title': title, 'content': value});
      }
    }

    add('Patient Name', summary['patient_name'] ?? widget.patient.name);
    add(
      'Medical Record Number',
      summary['registration_no'] ?? widget.patient.registrationNo,
    );
    add('Admission Date', _formatCertificateDate(summary['admission_date']));
    add('Discharge Date', _formatCertificateDate(summary['discharge_date']));
    add('Attending Physician', summary['attending_physician']);
    add('Consultant', summary['consultant_physician']);
    return fields;
  }

  String _summaryText(Map<String, dynamic> summary) {
    return [
      _pdfSafe('Discharge Summary: General Format'),
      '',
      for (final field in _summaryFields(summary))
        '${_pdfSafe(field['title']!)}: ${_pdfSafe(field['content']!)}',
      '',
      for (final section in _summarySections(summary))
        '${_pdfSafe(section['title']!)}\n${_pdfSafe(section['content']!)}',
    ].join('\n\n');
  }

  String? _formatCertificateDate(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }
}
