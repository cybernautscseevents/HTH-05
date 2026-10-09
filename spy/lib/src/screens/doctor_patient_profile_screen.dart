import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../auth_provider.dart';
import '../models/doctor_models.dart';
import '../theme.dart';
import '../widgets/watermark_background.dart';
import '../utils/speech_dictation_helper.dart';

class DoctorPatientProfileScreen extends StatefulWidget {
  final PatientSearchResult patient;

  const DoctorPatientProfileScreen({super.key, required this.patient});

  @override
  State<DoctorPatientProfileScreen> createState() =>
      _DoctorPatientProfileScreenState();
}

class _DoctorPatientProfileScreenState extends State<DoctorPatientProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<MockMedicalHistoryEntry> _history = [];
  List<MockVisit> _visits = [];
  List<MockReport> _reports = [];
  List<ApiMedicalHistory> _apiHistory = [];
  List<PortalAppointment> _appointments = [];
  int? _processingRescheduleRequestId;
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _loadClinicalData();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging ||
        _tabController.index == _lastTabIndex) {
      return;
    }
    _lastTabIndex = _tabController.index;
    if (_lastTabIndex == 2) _loadClinicalData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClinicalData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final regNo = widget.patient.registrationNo;
    final patientId = widget.patient.patientId;

    try {
      if (authProvider.useMockApi) {
        final history = await authProvider.mockApiClient
            .getPatientMedicalHistory(regNo);
        final visits = await authProvider.mockApiClient.getPatientVisits(regNo);
        final reports = await authProvider.mockApiClient.getPatientReports(
          regNo,
        );

        if (mounted) {
          setState(() {
            _history = history;
            _visits = visits;
            _reports = reports;
            _isLoading = false;
          });
        }
      } else {
        final token = authProvider.token;
        if (token == null) throw ApiException('Session expired.');

        final apiHistory = await authProvider.apiClient.getMedicalHistory(
          patientId,
          token: token,
        );
        final apiVisits = await authProvider.apiClient.getPatientVisits(
          patientId,
          token: token,
        );
        final apiReports = await authProvider.apiClient.getPatientReports(
          patientId,
          token: token,
        );
        final appointments = await authProvider.apiClient
            .getPatientAppointments(patientId, token: token);

        final history = apiHistory
            .map(
              (h) => MockMedicalHistoryEntry(
                date: _formatDate(h.startDate ?? h.createdAt),
                title:
                    '${h.medicineName ?? "Medication"} ${h.dosage ?? ""} ${h.frequency ?? ""}'
                        .trim(),
                description: h.reason ?? h.notes ?? 'No notes',
                status: 'Active',
              ),
            )
            .toList();

        final visits = apiVisits
            .map(
              (v) => MockVisit(
                visitId: v.visitId,
                date: _formatDate(v.visitDate ?? v.createdAt),
                visitType: v.visitType.isNotEmpty
                    ? v.visitType[0].toUpperCase() + v.visitType.substring(1)
                    : 'Consultation',
                admissionStatus: v.admissionStatus == 'admitted'
                    ? 'Admitted'
                    : 'Not admitted',
                dischargeStatus: v.dischargeStatus == 'discharged'
                    ? 'Discharged'
                    : v.dischargeStatus == null
                    ? null
                    : 'Not discharged',
                assignedDoctorName: v.assignedDoctorName,
                doctorName: 'Attending Physician',
                status: v.status.isNotEmpty
                    ? v.status[0].toUpperCase() + v.status.substring(1)
                    : 'Completed',
                reason: v.reason,
                notes: v.notes,
                temperature: v.temperature,
                bloodPressure: v.bloodPressure,
                pulse: v.pulse,
                spo2: v.spo2,
                weight: v.weight,
                height: v.height,
              ),
            )
            .toList();

        final reports = apiReports
            .map(
              (r) => MockReport(
                id: 'rep-${r.reportId}',
                visitId: r.visitId,
                title: 'Clinical Diagnosis',
                date: _formatDate(r.reportDatetime ?? r.createdAt),
                reportType: 'Clinical Encounter',
                summary: r.diagnosis,
                diagnosis: r.diagnosis,
                clinicalNotes: r.clinicalNotes,
                voiceTranscript: r.voiceTranscript,
                versionNo: r.versionNo,
                isFinal: r.isFinal,
              ),
            )
            .toList();

        if (mounted) {
          setState(() {
            _history = history;
            _visits = visits;
            _reports = reports;
            _apiHistory = apiHistory;
            _appointments = appointments;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return 'Not specified';
    try {
      final parsed = DateTime.parse(rawDate.trim());
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
      return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
    } catch (_) {
      return rawDate;
    }
  }

  String? _ageForDateOfBirth(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return null;

    final birthDate = DateTime.tryParse(rawDate.trim());
    if (birthDate == null) return null;

    final today = DateTime.now();
    if (birthDate.isAfter(today)) return null;

    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? null : '$age years';
  }

  void _openReportDialog(MockReport report) {
    showDialog(
      context: context,
      builder: (context) =>
          _DoctorReportViewerDialog(report: report, patient: widget.patient),
    );
  }

  void _startConsultationWorkflow({bool isFollowUp = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ConsultationWorkflowDialog(
        patient: widget.patient,
        isFollowUp: isFollowUp,
        onConsultationSaved: (visit, report) {
          setState(() {
            _visits.insert(0, visit);
            _reports.insert(0, report);
          });
          _tabController.animateTo(2); // Jump to Visits tab
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Consultation encounter and diagnosis report recorded successfully.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;

    return Scaffold(
      backgroundColor: saathiCream,
      body: WatermarkBackground(
        opacity: kHospitalWorkingWatermarkOpacity,
        spacing: kHospitalWorkingWatermarkSpacing,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation & Breadcrumbs
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back to Patients'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: saathiInk,
                        side: const BorderSide(color: saathiLine),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Patients',
                      style: TextStyle(
                        fontSize: 14,
                        color: saathiBodyGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('/', style: TextStyle(color: saathiBodyGrey)),
                    ),
                    const Text(
                      'Clinical Profile',
                      style: TextStyle(
                        fontSize: 14,
                        color: saathiNavy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Compact Clinical Header Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: saathiLine),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 16.0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: saathiGreen.withValues(alpha: 0.12),
                          child: Text(
                            patient.name.isNotEmpty
                                ? patient.name[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: saathiGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: saathiNavy,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: saathiMint,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      patient.registrationNo,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: saathiGreen,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  if (patient.diseaseCondition != null &&
                                      patient.diseaseCondition!
                                          .trim()
                                          .isNotEmpty)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.healing_outlined,
                                        size: 14,
                                        color: saathiTeal,
                                      ),
                                      label: Text(
                                        patient.diseaseCondition!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: saathiNavy,
                                        ),
                                      ),
                                      backgroundColor: saathiCream,
                                      side: const BorderSide(color: saathiLine),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _startConsultationWorkflow,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Start Consultation'),
                          style: FilledButton.styleFrom(
                            backgroundColor: saathiGreen,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _visits.isEmpty
                              ? null
                              : () => _startConsultationWorkflow(
                                  isFollowUp: true,
                                ),
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: const Text('Follow-up Consultation'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _visits.isEmpty
                                ? Colors.grey.shade300
                                : saathiGreen,
                            foregroundColor: _visits.isEmpty
                                ? Colors.grey.shade600
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Clinical Tabs Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: saathiLine),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: saathiGreen,
                    unselectedLabelColor: saathiBodyGrey,
                    indicatorColor: saathiGreen,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.dashboard_outlined, size: 18),
                        text: 'Overview',
                      ),
                      Tab(
                        icon: Icon(Icons.history_outlined, size: 18),
                        text: 'Medical History',
                      ),
                      Tab(
                        icon: Icon(Icons.calendar_today_outlined, size: 18),
                        text: 'Visits',
                      ),
                      Tab(
                        icon: Icon(Icons.assignment_outlined, size: 18),
                        text: 'Reports',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tab Content
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: saathiGreen),
                    ),
                  )
                else
                  _buildTabContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        switch (_tabController.index) {
          case 0:
            return _buildOverviewTab();
          case 1:
            return _buildMedicalHistoryTab();
          case 2:
            return _buildVisitsTab();
          case 3:
            return _buildReportsTab();
          default:
            return _buildOverviewTab();
        }
      },
    );
  }

  // ── Tab 1: Overview ───────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    final patient = widget.patient;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: saathiLine),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTwoCol = constraints.maxWidth > 500;
                if (isTwoCol) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInfoTile(
                              icon: Icons.calendar_today_outlined,
                              label: 'Date of Birth',
                              value: _formatDate(patient.dateOfBirth),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildInfoTile(
                              icon: Icons.person_outline_rounded,
                              label: 'Patient Age',
                              value:
                                  _ageForDateOfBirth(patient.dateOfBirth) ??
                                  'Not available',
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: saathiLine),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInfoTile(
                              icon: Icons.medical_services_outlined,
                              label: 'Primary Condition',
                              value:
                                  patient.diseaseCondition?.trim().isNotEmpty ==
                                      true
                                  ? patient.diseaseCondition!
                                  : 'Not specified',
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildInfoTile(
                              icon: Icons.language_outlined,
                              label: 'Preferred Language',
                              value: patient.preferredLanguage.isNotEmpty
                                  ? patient.preferredLanguage
                                  : 'English',
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildInfoTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date of Birth',
                      value: _formatDate(patient.dateOfBirth),
                    ),
                    const Divider(height: 20, color: saathiLine),
                    _buildInfoTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Patient Age',
                      value:
                          _ageForDateOfBirth(patient.dateOfBirth) ??
                          'Not available',
                    ),
                    const Divider(height: 20, color: saathiLine),
                    _buildInfoTile(
                      icon: Icons.medical_services_outlined,
                      label: 'Primary Condition',
                      value: patient.diseaseCondition?.trim().isNotEmpty == true
                          ? patient.diseaseCondition!
                          : 'Not specified',
                    ),
                    const Divider(height: 20, color: saathiLine),
                    _buildInfoTile(
                      icon: Icons.language_outlined,
                      label: 'Preferred Language',
                      value: patient.preferredLanguage.isNotEmpty
                          ? patient.preferredLanguage
                          : 'English',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Clinical Notice
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: saathiMint.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: saathiLine),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: saathiGreen, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Demonstration Clinical Overview: This section presents current patient identifiers, diagnostic baseline, and structured records for the Saathi Doctor Portal prototype.',
                  style: TextStyle(
                    fontSize: 13,
                    color: saathiNavy,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Medical History ────────────────────────────────────────────────

  Widget _buildMedicalHistoryTab() {
    if (_history.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_outlined,
        title: 'No medical history available',
        subtitle:
            'Clinical history will appear here when records are available.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _history[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: saathiLine),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: saathiCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: saathiLine),
                  ),
                  child: const Icon(
                    Icons.event_note,
                    color: saathiNavy,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: saathiNavy,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: saathiMint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.status,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: saathiGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.date,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: saathiBodyGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: saathiInk,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab 3: Visits ─────────────────────────────────────────────────────────

  Widget _buildVisitsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAppointmentsSection(),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: saathiLine),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: saathiGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Visits & Encounters (${_visits.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: saathiNavy,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _showScheduleAppointmentDialog,
                  icon: const Icon(Icons.add_alarm_rounded, size: 16),
                  label: const Text('Assign Next Appointment'),
                  style: FilledButton.styleFrom(
                    backgroundColor: saathiGreen,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_visits.isEmpty)
          _buildEmptyState(
            icon: Icons.calendar_today_outlined,
            title: 'No visits recorded',
            subtitle: 'Click "Assign Next Appointment" above or record a consultation.',
          )
        else
          _buildVisitsList(),
      ],
    );
  }

  Widget _buildAppointmentsSection() {
    final now = DateTime.now();
    final upcoming = _appointments
        .where(
          (appointment) =>
              appointment.status == 'scheduled' &&
              appointment.appointmentDatetime.isAfter(now),
        )
        .toList();
    final history = _appointments
        .where((appointment) => !upcoming.contains(appointment))
        .toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: saathiLine),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  color: saathiGreen,
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Appointments (${_appointments.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: saathiNavy,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh appointments',
                  onPressed: _loadClinicalData,
                  icon: const Icon(Icons.refresh_rounded),
                  color: saathiGreen,
                ),
              ],
            ),
            if (_appointments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No appointments have been assigned.',
                  style: TextStyle(color: saathiBodyGrey),
                ),
              )
            else ...[
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'UPCOMING',
                  style: TextStyle(
                    color: saathiBodyGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                for (final appointment in upcoming) ...[
                  _buildAppointmentCard(appointment),
                  const SizedBox(height: 9),
                ],
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'APPOINTMENT HISTORY',
                  style: TextStyle(
                    color: saathiBodyGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                for (final appointment in history) ...[
                  _buildAppointmentCard(appointment),
                  const SizedBox(height: 9),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(PortalAppointment appointment) {
    final request = appointment.rescheduleRequest;
    final hasPendingRequest = request?.status == 'pending';
    final statusLabel = hasPendingRequest
        ? 'RESCHEDULE REQUESTED'
        : appointment.status.toUpperCase();
    final statusColor = switch (appointment.status) {
      'cancelled' => saathiEmergencyDeep,
      'completed' => saathiGreen,
      'missed' => saathiBodyGrey,
      _ when hasPendingRequest => const Color(0xFF9A6700),
      _ => saathiTeal,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: saathiCream.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: saathiLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _formatAppointmentDateTime(appointment.appointmentDatetime),
                  style: const TextStyle(
                    color: saathiNavy,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Patient: ${appointment.patientName}',
            style: const TextStyle(color: saathiInk, fontSize: 13),
          ),
          if (appointment.reason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: ${appointment.reason}',
              style: const TextStyle(color: saathiBodyGrey, fontSize: 13),
            ),
          ],
          if (appointment.status == 'cancelled') ...[
            const SizedBox(height: 7),
            const Text(
              'Cancelled by patient',
              style: TextStyle(
                color: saathiEmergencyDeep,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (request != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8D59A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.status == 'pending'
                        ? 'Reschedule Request'
                        : 'Reschedule Request • ${request.status.toUpperCase()}',
                    style: const TextStyle(
                      color: saathiNavy,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Current: ${_formatAppointmentDateTime(appointment.appointmentDatetime)}',
                    style: const TextStyle(color: saathiInk, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Preferred: ${_formatAppointmentDateTime(request.preferredDatetime)}',
                    style: const TextStyle(
                      color: saathiNavy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (request.reason?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Reason: ${request.reason}',
                      style: const TextStyle(color: saathiInk, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    'Status: ${request.status[0].toUpperCase()}${request.status.substring(1)}',
                    style: const TextStyle(color: saathiBodyGrey, fontSize: 12),
                  ),
                  if (hasPendingRequest) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              _processingRescheduleRequestId ==
                                  request.requestId
                              ? null
                              : () => _decideReschedule(request, approve: true),
                          icon: const Icon(Icons.check_rounded, size: 17),
                          label: const Text('Approve'),
                          style: FilledButton.styleFrom(
                            backgroundColor: saathiGreen,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _processingRescheduleRequestId ==
                                  request.requestId
                              ? null
                              : () =>
                                    _decideReschedule(request, approve: false),
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: saathiEmergencyDeep,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatAppointmentDateTime(DateTime value) {
    final time = _formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '${value.day} ${_monthNameShort(value.month)} ${value.year} • $time';
  }

  Future<void> _decideReschedule(
    AppointmentRescheduleInfo request, {
    required bool approve,
  }) async {
    final action = approve ? 'approve' : 'reject';
    final outcome = approve ? 'approved' : 'rejected';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${approve ? 'Approve' : 'Reject'} reschedule request?'),
        content: Text(
          approve
              ? 'The confirmed appointment will move to ${_formatAppointmentDateTime(request.preferredDatetime)}.'
              : 'The current appointment time will remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Pending'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingRescheduleRequestId = request.requestId);
    final auth = context.read<AuthProvider>();
    try {
      await auth.apiClient.decideRescheduleRequest(
        request.requestId,
        approve: approve,
        token: auth.token!,
      );
      await _loadClinicalData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reschedule request $outcome.'),
            backgroundColor: approve ? saathiGreen : saathiBodyGrey,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to $action request: $error'),
            backgroundColor: saathiEmergency,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingRescheduleRequestId = null);
    }
  }

  Widget _buildVisitsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _visits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final visit = _visits[index];
        final hasVitals =
            visit.temperature != null ||
            visit.bloodPressure != null ||
            visit.pulse != null ||
            visit.spo2 != null ||
            visit.weight != null ||
            visit.height != null;
        final meds = visit.visitId != null
            ? _apiHistory.where((h) => h.visitId == visit.visitId).toList()
            : <ApiMedicalHistory>[];

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: saathiLine),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: saathiCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: saathiLine),
                  ),
                  child: const Icon(
                    Icons.local_hospital_outlined,
                    color: saathiGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              visit.visitType,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: saathiNavy,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: saathiMint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              visit.status,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: saathiGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: saathiBodyGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            visit.date,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: saathiBodyGrey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.person_outline,
                            size: 13,
                            color: saathiBodyGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            visit.doctorName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: saathiBodyGrey,
                            ),
                          ),
                        ],
                      ),
                      if (visit.assignedDoctorName != null &&
                          visit.assignedDoctorName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.assignment_ind_outlined,
                              size: 13,
                              color: saathiBodyGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Assigned doctor: ${visit.assignedDoctorName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: saathiBodyGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (visit.dischargeStatus != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Discharge status: ${visit.dischargeStatus}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: saathiBodyGrey,
                          ),
                        ),
                      ],
                      // Vitals display
                      if (hasVitals) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Patient Vitals:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: saathiNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (visit.temperature != null)
                              Text(
                                'Temp: ${visit.temperature}°C',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: saathiInk,
                                ),
                              ),
                            if (visit.bloodPressure != null)
                              Text(
                                'BP: ${visit.bloodPressure} mmHg',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: saathiInk,
                                ),
                              ),
                            if (visit.pulse != null)
                              Text(
                                'Pulse: ${visit.pulse} bpm',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: saathiInk,
                                ),
                              ),
                            if (visit.spo2 != null)
                              Text(
                                'SpO2: ${visit.spo2}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: saathiInk,
                                ),
                              ),
                            if (visit.weight != null)
                              Text(
                                'Wt: ${visit.weight} kg',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: saathiInk,
                                ),
                              ),
                            if (visit.height != null)
                              Text(
                                'Ht: ${visit.height} cm',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: saathiInk,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (visit.notes != null && visit.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          visit.notes!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: saathiInk,
                            height: 1.4,
                          ),
                        ),
                      ],
                      // Prescription (medicines) display
                      if (meds.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Prescription:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: saathiNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: saathiCream,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: saathiLine),
                          ),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1.2),
                              2: FlexColumnWidth(1.5),
                              3: FlexColumnWidth(1.5),
                            },
                            children: [
                              const TableRow(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Text(
                                      'Medicine',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Text(
                                      'Dose',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Text(
                                      'Freq',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Text(
                                      'Instructions',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              for (final med in meds)
                                TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Text(
                                        med.medicineName ?? "-",
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Text(
                                        med.dosage ?? "-",
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Text(
                                        med.frequency ?? "-",
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Text(
                                        med.notes ?? "-",
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _monthNameShort(int m) {
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
    if (m >= 1 && m <= 12) return months[m - 1];
    return '';
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final min = tod.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  Future<void> _showScheduleAppointmentDialog() async {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 30);
    final reasonController = TextEditingController(
      text: 'Follow-up consultation',
    );
    final notesController = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: saathiMint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: saathiGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Assign Next Appointment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: saathiNavy,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Appointment Date & Time *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: saathiInk,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                              ),
                              label: Text(
                                '${selectedDate.day} ${_monthNameShort(selectedDate.month)} ${selectedDate.year}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: dialogCtx,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.access_time_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _formatTimeOfDay(selectedTime),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: dialogCtx,
                                  initialTime: selectedTime,
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedTime = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Reason / Visit Type',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: saathiInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          hintText:
                              'e.g. Follow-up consultation, Review lab tests',
                          prefixIcon: Icon(Icons.help_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Instructions / Notes for Patient (Optional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: saathiInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText:
                              'e.g. Please bring fasting blood test report',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: saathiBodyGrey),
                  ),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final auth = context.read<AuthProvider>();
                          final apptDateTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );
                          try {
                            await auth.apiClient.createAppointment(
                              widget.patient.patientId,
                              appointmentDatetime: apptDateTime
                                  .toIso8601String(),
                              reason: reasonController.text.trim().isNotEmpty
                                  ? reasonController.text.trim()
                                  : 'Follow-up consultation',
                              notes: notesController.text.trim().isNotEmpty
                                  ? notesController.text.trim()
                                  : null,
                              token: auth.token!,
                            );
                            if (mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Appointment successfully assigned for ${selectedDate.day} ${_monthNameShort(selectedDate.month)} ${selectedDate.year}, ${_formatTimeOfDay(selectedTime)}.',
                                  ),
                                  backgroundColor: saathiGreen,
                                ),
                              );
                              _loadClinicalData();
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to assign appointment: $e',
                                  ),
                                  backgroundColor: saathiEmergency,
                                ),
                              );
                            }
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: const Text('Assign Appointment'),
                  style: FilledButton.styleFrom(backgroundColor: saathiGreen),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Tab 4: Reports ────────────────────────────────────────────────────────

  Widget _buildReportsTab() {
    if (_reports.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No reports recorded',
        subtitle:
            'Diagnostic and clinical reports will appear here when available.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final report = _reports[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: saathiLine),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: saathiCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: saathiLine),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: saathiTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: saathiNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            report.date,
                            style: const TextStyle(
                              fontSize: 12,
                              color: saathiBodyGrey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: saathiMint,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              report.reportType,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: saathiGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _openReportDialog(report),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    foregroundColor: saathiTeal,
                    side: const BorderSide(color: saathiTeal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: saathiLine),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: saathiBodyGrey.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: saathiNavy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: saathiBodyGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: saathiCream,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: saathiLine),
          ),
          child: Icon(icon, size: 18, color: saathiNavy),
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
                  fontWeight: FontWeight.w600,
                  color: saathiBodyGrey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: saathiInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoctorReportViewerDialog extends StatelessWidget {
  final MockReport report;
  final PatientSearchResult patient;

  const _DoctorReportViewerDialog({
    required this.report,
    required this.patient,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: saathiMint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.assessment_outlined,
                          color: saathiGreen,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: saathiNavy,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: saathiBodyGrey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: saathiLine, height: 24),

              // Patient & Report Metadata
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PATIENT',
                        style: TextStyle(
                          fontSize: 11,
                          color: saathiBodyGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: saathiInk,
                        ),
                      ),
                      Text(
                        patient.registrationNo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: saathiGreen,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'DATE',
                        style: TextStyle(
                          fontSize: 11,
                          color: saathiBodyGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.date,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: saathiInk,
                        ),
                      ),
                      Text(
                        report.reportType,
                        style: const TextStyle(
                          fontSize: 12,
                          color: saathiTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (report.visitId != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: saathiCream,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: saathiLine),
                  ),
                  child: Text(
                    'Associated Visit Reference: #${report.visitId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: saathiBodyGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Demo Report Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: saathiAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: saathiAmber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.science_outlined, color: saathiAmber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demo Report — This report is a demonstration record for the Saathi prototype.',
                        style: TextStyle(
                          fontSize: 12,
                          color: saathiAmber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Diagnosis Section
              if (report.diagnosis != null && report.diagnosis!.isNotEmpty) ...[
                const Text(
                  'Diagnosis',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: saathiNavy,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: saathiCream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: saathiLine),
                  ),
                  child: Text(
                    report.diagnosis!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: saathiInk,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Clinical Notes
              if (report.clinicalNotes != null &&
                  report.clinicalNotes!.isNotEmpty) ...[
                const Text(
                  'Clinical Notes & Observations',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: saathiNavy,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: saathiCream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: saathiLine),
                  ),
                  child: Text(
                    report.clinicalNotes!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: saathiInk,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Voice Transcript
              if (report.voiceTranscript != null &&
                  report.voiceTranscript!.isNotEmpty) ...[
                const Text(
                  'Voice Dictation Transcript',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: saathiNavy,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: saathiMint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: saathiLine),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.mic, size: 16, color: saathiGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report.voiceTranscript!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: saathiInk,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Summary Content
              const Text(
                'Summary & Findings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: saathiNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                report.summary,
                style: const TextStyle(
                  fontSize: 13,
                  color: saathiBodyGrey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    backgroundColor: saathiNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Medicine Reminder Schedule Data Class ──────────────────────────────────

class _MedicineReminderSchedule {
  String medicineName;
  String medicineType;
  String dosage;
  DateTime fromDate;
  DateTime toDate;
  List<TimeOfDay> reminderTimes;
  String mealTiming;
  String instructions;

  _MedicineReminderSchedule({
    required this.medicineName,
    this.medicineType = 'Tablet',
    this.dosage = '1 tablet',
    required this.fromDate,
    required this.toDate,
    required this.reminderTimes,
    this.mealTiming = 'After Food',
    this.instructions = '',
  });
}

// ── Doctor Consultation & Report Workflow Dialog ───────────────────────────

class _ConsultationWorkflowDialog extends StatefulWidget {
  final PatientSearchResult patient;
  final bool isFollowUp;
  final void Function(MockVisit visit, MockReport report) onConsultationSaved;

  const _ConsultationWorkflowDialog({
    required this.patient,
    this.isFollowUp = false,
    required this.onConsultationSaved,
  });

  @override
  State<_ConsultationWorkflowDialog> createState() =>
      _ConsultationWorkflowDialogState();
}

class _ConsultationWorkflowDialogState
    extends State<_ConsultationWorkflowDialog> {
  final _formKey = GlobalKey<FormState>();

  // Step 1: Visit & Vitals fields
  String _visitType = 'Consultation';
  final _visitReasonController = TextEditingController();
  final _visitNotesController = TextEditingController();
  final _tempController = TextEditingController();
  final _bpController = TextEditingController();
  final _pulseController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  // Step 2: Prescription fields
  final List<PrescriptionItemInput> _medicines = [];
  final _medNameController = TextEditingController();
  final _medDosageController = TextEditingController();
  final _medFreqController = TextEditingController();
  final _medDurationController = TextEditingController();
  final _medInstController = TextEditingController();
  String _medType = 'Tablet';
  int? _editingMedIndex;

  // Step 3: Report fields
  final _diagnosisController = TextEditingController();
  final _clinicalNotesController = TextEditingController();
  final _voiceTranscriptController = TextEditingController();
  bool _isAdmitted = false;
  bool _isDischarged = false;
  bool _isFinal = true;
  List<DoctorInfo> _otherDoctors = [];
  bool _loadingOtherDoctors = false;
  int? _selectedOtherDoctorId;

  // Step 4: Medicine Reminders fields
  final List<_MedicineReminderSchedule> _reminders = [];
  String? _selectedReminderMedName;
  String _reminderMedType = 'Tablet';
  DateTime _reminderFromDate = DateTime.now();
  DateTime _reminderToDate = DateTime.now().add(const Duration(days: 5));
  List<TimeOfDay> _currentReminderTimes = [
    const TimeOfDay(hour: 8, minute: 0),
    const TimeOfDay(hour: 20, minute: 0),
  ];
  String _reminderMealTiming = 'After Food';
  final _reminderDosageController = TextEditingController(text: '1 tablet');
  final _reminderInstController = TextEditingController();
  final _reminderCustomMedController = TextEditingController();
  int? _editingReminderIndex;

  int _currentStep =
      0; // 0 = Encounter, 1 = Prescription, 2 = Report, 3 = Medicine Reminders
  bool _isSaving = false;

  // Voice Dictation (Talk-to-Type)
  TextEditingController? _activeTargetController;
  String _activeTargetName = 'Consultation Notes';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _activeTargetController = _visitNotesController;
    _activeTargetName = 'Consultation Notes';
    _loadOtherDoctors();
  }

  Future<void> _loadOtherDoctors() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (auth.useMockApi || token == null) return;
    setState(() => _loadingOtherDoctors = true);
    try {
      final doctors = await auth.apiClient.getDoctors(token: token);
      if (!mounted) return;
      setState(() => _otherDoctors = doctors);
    } catch (_) {
      if (!mounted) return;
      setState(() => _otherDoctors = []);
    } finally {
      if (mounted) setState(() => _loadingOtherDoctors = false);
    }
  }

  void _setActiveTargetField(TextEditingController controller, String name) {
    if (_activeTargetController != controller) {
      setState(() {
        _activeTargetController = controller;
        _activeTargetName = name;
      });
    }
  }

  Future<void> _toggleDictation() async {
    if (_isListening) {
      await SpeechDictationHelper.instance.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (_activeTargetController == null) {
      if (_currentStep == 0) {
        _setActiveTargetField(_visitNotesController, 'Consultation Notes');
      } else if (_currentStep == 1) {
        _setActiveTargetField(_medNameController, 'Medicine Name');
      } else {
        _setActiveTargetField(_diagnosisController, 'Clinical Diagnosis');
      }
    }

    final started = await SpeechDictationHelper.instance.startListening(
      onResult: (words, isFinal) {
        if (!mounted || _activeTargetController == null) return;
        final cleanWords = words.trim();
        if (cleanWords.isEmpty) return;
        setState(() {
          // Speech recognition callbacks contain the current utterance.  The
          // active field must show that latest value, not append prior speech.
          _activeTargetController!.text = _formatVoiceValue(
            _activeTargetController!,
            cleanWords,
          );
          _activeTargetController!.selection = TextSelection.fromPosition(
            TextPosition(offset: _activeTargetController!.text.length),
          );
        });
      },
      onStopped: () {
        if (mounted) setState(() => _isListening = false);
      },
      onError: (errorMsg) {
        if (!mounted) return;
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: saathiEmergency,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );

    if (mounted) setState(() => _isListening = started);
  }

  String _formatVoiceValue(TextEditingController controller, String value) {
    if (controller != _tempController) return value;

    // Keep temperature consistently stored and displayed with its unit. This
    // accepts phrases such as "thirty seven point five degrees" as well as a
    // numeric transcription from the browser.
    final number = RegExp(r'\d+(?:\.\d+)?').firstMatch(value)?.group(0);
    return number == null ? value : number;
  }

  double? _firstVitalNumber(TextEditingController controller) {
    return double.tryParse(
      RegExp(r'\d+(?:\.\d+)?').firstMatch(controller.text)?.group(0) ?? '',
    );
  }

  String? _optionalPositiveVital(String? value, String label) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.trim());
    if (number == null || number <= 0) return 'Enter a positive $label';
    return null;
  }

  String? _bloodPressureValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final values = RegExp(r'^\s*(\d{2,3})\s*/\s*(\d{2,3})\s*$')
        .firstMatch(value);
    if (values == null ||
        int.parse(values.group(1)!) == 0 ||
        int.parse(values.group(2)!) == 0) {
      return 'Use systolic/diastolic, e.g. 120/80';
    }
    return null;
  }

  String? _spo2Validator(String? value) {
    final base = _optionalPositiveVital(value, 'SpO₂ value');
    if (base != null) return base;
    if (value != null &&
        value.trim().isNotEmpty &&
        double.parse(value.trim()) > 100)
      return 'SpO₂ must be 100 or less';
    return null;
  }

  String? _vitalsWarning() {
    final warnings = <String>[];
    final temperature = _firstVitalNumber(_tempController);
    final pulse = _firstVitalNumber(_pulseController);
    final spo2 = _firstVitalNumber(_spo2Controller);
    final bpValues = RegExp(r'\d+(?:\.\d+)?')
        .allMatches(_bpController.text)
        .map((match) => double.tryParse(match.group(0)!))
        .whereType<double>()
        .toList();

    if (temperature != null && (temperature < 35 || temperature > 37.5)) {
      warnings.add(
        'Temperature ${temperature > 37.5 ? 'is elevated' : 'is low'}',
      );
    }
    if (bpValues.length >= 2 &&
        (bpValues[0] >= 140 ||
            bpValues[1] >= 90 ||
            bpValues[0] < 90 ||
            bpValues[1] < 60)) {
      warnings.add('Blood pressure is outside the normal adult range');
    }
    if (pulse != null && (pulse < 60 || pulse > 100)) {
      warnings.add('Pulse is outside the normal adult range');
    }
    if (spo2 != null && spo2 < 95) {
      warnings.add('SpO₂ is below the normal adult range');
    }
    return warnings.isEmpty ? null : warnings.join(' • ');
  }

  Widget _buildVitalsWarning() {
    final warning = _vitalsWarning();
    if (warning == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: saathiEmergency.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: saathiEmergency.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: saathiEmergency,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Vital warning: $warning',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: saathiEmergency,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicOption() {
    return InkWell(
      onTap: _toggleDictation,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _isListening
              ? Colors.red.withValues(alpha: 0.12)
              : saathiGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isListening
                ? Colors.red
                : saathiGreen.withValues(alpha: 0.4),
            width: _isListening ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.red : saathiGreen,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              _isListening
                  ? 'Listening: $_activeTargetName...'
                  : 'Talk to Type ($_activeTargetName)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isListening ? Colors.red.shade700 : saathiGreen,
              ),
            ),
            if (_isListening) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _fieldSuffix(TextEditingController controller) {
    if (_activeTargetController != controller) return null;
    return Tooltip(
      message: 'Active for voice typing',
      child: Icon(
        _isListening ? Icons.mic : Icons.mic_none,
        size: 18,
        color: _isListening ? Colors.red : saathiGreen,
      ),
    );
  }

  Widget _temperatureSuffix() {
    final mic = _fieldSuffix(_tempController);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '°C',
          style: TextStyle(fontWeight: FontWeight.w600, color: saathiBodyGrey),
        ),
        if (mic != null) mic,
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  void dispose() {
    SpeechDictationHelper.instance.stopListening();
    _visitReasonController.dispose();
    _visitNotesController.dispose();
    _tempController.dispose();
    _bpController.dispose();
    _pulseController.dispose();
    _spo2Controller.dispose();
    _weightController.dispose();
    _heightController.dispose();

    _medNameController.dispose();
    _medDosageController.dispose();
    _medFreqController.dispose();
    _medDurationController.dispose();
    _medInstController.dispose();

    _diagnosisController.dispose();
    _clinicalNotesController.dispose();
    _voiceTranscriptController.dispose();

    _reminderDosageController.dispose();
    _reminderInstController.dispose();
    _reminderCustomMedController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _apiDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  void _syncMedicinesToReminders() {
    for (final med in _medicines) {
      final alreadyExists = _reminders.any(
        (r) => r.medicineName.toLowerCase() == med.medicineName.toLowerCase(),
      );
      if (!alreadyExists) {
        final digits = RegExp(r'\d+').firstMatch(med.duration ?? '')?.group(0);
        final days = int.tryParse(digits ?? '5') ?? 5;
        final from = DateTime.now();
        final to = from.add(Duration(days: days > 1 ? days - 1 : 0));

        final freq = (med.frequency ?? '').toLowerCase();
        List<TimeOfDay> times;
        if (freq.contains('3') ||
            freq.contains('thrice') ||
            freq.contains('tid')) {
          times = [
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 13, minute: 0),
            const TimeOfDay(hour: 20, minute: 0),
          ];
        } else if (freq.contains('2') ||
            freq.contains('twice') ||
            freq.contains('bid') ||
            freq.contains('2x')) {
          times = [
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 20, minute: 0),
          ];
        } else if (freq.contains('night') ||
            freq.contains('bed') ||
            freq.contains('hs')) {
          times = [const TimeOfDay(hour: 21, minute: 0)];
        } else {
          times = [const TimeOfDay(hour: 8, minute: 0)];
        }

        String meal = 'After Food';
        if (med.instructions?.toLowerCase().contains('before') == true) {
          meal = 'Before Food';
        } else if (med.instructions?.toLowerCase().contains('empty') == true) {
          meal = 'Empty Stomach';
        }

        _reminders.add(
          _MedicineReminderSchedule(
            medicineName: med.medicineName,
            medicineType: med.medicineType ?? 'Tablet',
            dosage: med.dosage != null && med.dosage!.isNotEmpty
                ? med.dosage!
                : '1 tablet',
            fromDate: from,
            toDate: to,
            reminderTimes: times,
            mealTiming: meal,
            instructions: med.instructions ?? '',
          ),
        );
      }
    }

    if (_reminders.isNotEmpty && _selectedReminderMedName == null) {
      _selectedReminderMedName = _reminders.first.medicineName;
      _reminderMedType = _reminders.first.medicineType;
    } else if (_medicines.isNotEmpty && _selectedReminderMedName == null) {
      _selectedReminderMedName = _medicines.first.medicineName;
      _reminderMedType = _medicines.first.medicineType ?? 'Tablet';
    }
  }

  void _togglePresetTime(TimeOfDay tod) {
    setState(() {
      final index = _currentReminderTimes.indexWhere(
        (t) => t.hour == tod.hour && t.minute == tod.minute,
      );
      if (index >= 0) {
        if (_currentReminderTimes.length > 1) {
          _currentReminderTimes.removeAt(index);
        }
      } else {
        _currentReminderTimes.add(tod);
        _currentReminderTimes.sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
        );
      }
    });
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        final exists = _currentReminderTimes.any(
          (t) => t.hour == picked.hour && t.minute == picked.minute,
        );
        if (!exists) {
          _currentReminderTimes.add(picked);
          _currentReminderTimes.sort(
            (a, b) =>
                (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
          );
        }
      });
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reminderFromDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _reminderFromDate = picked;
        if (_reminderToDate.isBefore(_reminderFromDate)) {
          _reminderToDate = _reminderFromDate.add(const Duration(days: 5));
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reminderToDate.isAfter(_reminderFromDate)
          ? _reminderToDate
          : _reminderFromDate,
      firstDate: _reminderFromDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _reminderToDate = picked;
      });
    }
  }

  void _editReminder(int idx) {
    final rem = _reminders[idx];
    setState(() {
      _editingReminderIndex = idx;
      _selectedReminderMedName = rem.medicineName;
      _reminderMedType = rem.medicineType;
      _reminderFromDate = rem.fromDate;
      _reminderToDate = rem.toDate;
      _currentReminderTimes = List.from(rem.reminderTimes);
      _reminderMealTiming = rem.mealTiming;
      _reminderDosageController.text = rem.dosage;
      _reminderInstController.text = rem.instructions;
    });
  }

  void _saveOrUpdateReminder() {
    final medName =
        (_selectedReminderMedName == '+ Other Custom Medicine...' ||
            _selectedReminderMedName == null)
        ? _reminderCustomMedController.text.trim()
        : _selectedReminderMedName!;

    if (medName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a medicine name'),
          backgroundColor: saathiEmergency,
        ),
      );
      return;
    }

    if (_currentReminderTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one reminder time'),
          backgroundColor: saathiEmergency,
        ),
      );
      return;
    }

    final schedule = _MedicineReminderSchedule(
      medicineName: medName,
      medicineType: _reminderMedType,
      dosage: _reminderDosageController.text.trim().isNotEmpty
          ? _reminderDosageController.text.trim()
          : '1 tablet',
      fromDate: _reminderFromDate,
      toDate: _reminderToDate,
      reminderTimes: List.from(_currentReminderTimes),
      mealTiming: _reminderMealTiming,
      instructions: _reminderInstController.text.trim(),
    );

    setState(() {
      if (_editingReminderIndex != null) {
        _reminders[_editingReminderIndex!] = schedule;
        _editingReminderIndex = null;
      } else {
        final existingIdx = _reminders.indexWhere(
          (r) => r.medicineName.toLowerCase() == medName.toLowerCase(),
        );
        if (existingIdx >= 0) {
          _reminders[existingIdx] = schedule;
        } else {
          _reminders.add(schedule);
        }
      }

      _reminderCustomMedController.clear();
      _reminderInstController.clear();
      _reminderDosageController.text = '1 tablet';
      _currentReminderTimes = [
        const TimeOfDay(hour: 8, minute: 0),
        const TimeOfDay(hour: 20, minute: 0),
      ];
    });
  }

  Widget _buildStepTab(int stepIndex, String number, String title) {
    final isActive = _currentStep == stepIndex;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (stepIndex == 3) {
            if (_diagnosisController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a clinical diagnosis first'),
                  backgroundColor: saathiEmergency,
                ),
              );
              return;
            }
            _syncMedicinesToReminders();
          }
          setState(() => _currentStep = stepIndex);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? saathiMint : saathiCream,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? saathiGreen : saathiLine),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: isActive ? saathiGreen : saathiBodyGrey,
                child: Text(
                  number,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: saathiNavy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveConsultation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final now = DateTime.now();
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
    final formattedDate = '${now.day} ${months[now.month - 1]} ${now.year}';
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final diagnosisText = _diagnosisController.text.trim();
    final clinicalNotesText = _clinicalNotesController.text.trim();
    final transcriptText = _voiceTranscriptController.text.trim();
    final reasonText = _visitReasonController.text.trim();
    final notesText = _visitNotesController.text.trim();
    final tempText = _tempController.text.trim();
    final bpText = _bpController.text.trim();
    final pulseText = _pulseController.text.trim();
    final spo2Text = _spo2Controller.text.trim();
    final weightText = _weightController.text.trim();
    final heightText = _heightController.text.trim();

    // Prepare synchronized prescription medicines with reminder schedule data
    final finalMedicines = <PrescriptionItemInput>[];
    if (_medicines.isNotEmpty) {
      for (final med in _medicines) {
        final reminder = _reminders.firstWhere(
          (r) => r.medicineName.toLowerCase() == med.medicineName.toLowerCase(),
          orElse: () => _MedicineReminderSchedule(
            medicineName: med.medicineName,
            medicineType: med.medicineType ?? 'Tablet',
            dosage: med.dosage ?? '1 tablet',
            fromDate: DateTime.now(),
            toDate: DateTime.now().add(const Duration(days: 5)),
            reminderTimes: [const TimeOfDay(hour: 8, minute: 0)],
            mealTiming: 'After Food',
          ),
        );

        final timeStrings = reminder.reminderTimes.map(_formatTime).join(', ');
        final durationDays =
            reminder.toDate.difference(reminder.fromDate).inDays + 1;

        final instructions = [med.instructions, reminder.instructions]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .join(' • ');

        finalMedicines.add(
          PrescriptionItemInput(
            medicineId: med.medicineId,
            medicineName: med.medicineName,
            genericName: med.genericName,
            medicineType: med.medicineType,
            strength: med.strength,
            dosage: reminder.dosage.isNotEmpty ? reminder.dosage : med.dosage,
            frequency: '${reminder.reminderTimes.length}x daily ($timeStrings)',
            duration: '$durationDays days',
            instructions: instructions.isEmpty ? null : instructions,
            foodTiming: reminder.mealTiming,
            route: med.route,
            startDate: _apiDate(reminder.fromDate),
            endDate: _apiDate(reminder.toDate),
            reminderTimes: reminder.reminderTimes
                .map((time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00')
                .toList(),
          ),
        );
      }
    } else {
      for (final rem in _reminders) {
        final timeStrings = rem.reminderTimes.map(_formatTime).join(', ');
        final durationDays = rem.toDate.difference(rem.fromDate).inDays + 1;
        finalMedicines.add(
          PrescriptionItemInput(
            medicineName: rem.medicineName,
            medicineType: rem.medicineType,
            dosage: rem.dosage,
            frequency: '${rem.reminderTimes.length}x daily ($timeStrings)',
            duration: '$durationDays days',
            instructions: rem.instructions.isNotEmpty ? rem.instructions : null,
            foodTiming: rem.mealTiming,
            startDate: _apiDate(rem.fromDate),
            endDate: _apiDate(rem.toDate),
            reminderTimes: rem.reminderTimes
                .map((time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00')
                .toList(),
          ),
        );
      }
    }

    try {
      if (authProvider.useMockApi) {
        final generatedVisitId = now.millisecondsSinceEpoch ~/ 1000;
        final createdVisit = MockVisit(
          visitId: generatedVisitId,
          date: formattedDate,
          visitType: widget.isFollowUp ? 'Follow-up Consultation' : _visitType,
          admissionStatus: widget.isFollowUp
              ? 'Not admitted'
              : (_isAdmitted ? 'Admitted' : 'Not admitted'),
          dischargeStatus: widget.isFollowUp
              ? (_isDischarged ? 'Discharged' : 'Not discharged')
              : null,
          assignedDoctorName: _otherDoctors
              .where((doctor) => doctor.staffId == _selectedOtherDoctorId)
              .firstOrNull
              ?.name,
          doctorName: 'Dr. Sharma',
          status: 'Completed',
          reason: reasonText.isNotEmpty ? reasonText : null,
          notes: notesText.isNotEmpty ? notesText : null,
        );

        final createdReport = MockReport(
          id: 'rep-$generatedVisitId',
          visitId: generatedVisitId,
          title:
              '${widget.isFollowUp ? 'Follow-up Consultation' : _visitType} Report',
          date: formattedDate,
          reportType: 'Clinical Encounter',
          summary: diagnosisText,
          diagnosis: diagnosisText,
          clinicalNotes: clinicalNotesText.isNotEmpty
              ? clinicalNotesText
              : null,
          voiceTranscript: transcriptText.isNotEmpty ? transcriptText : null,
          versionNo: 1,
          isFinal: _isFinal,
        );

        widget.onConsultationSaved(createdVisit, createdReport);
        if (mounted) Navigator.pop(context);
      } else {
        final token = authProvider.token;
        if (token == null)
          throw ApiException('Session expired. Please sign in again.');

        // Unified Transaction endpoint call
        final response = await authProvider.apiClient.createConsultation(
          widget.patient.patientId,
          visitType: widget.isFollowUp
              ? 'follow-up consultation'
              : _visitType.toLowerCase(),
          admissionStatus: widget.isFollowUp
              ? null
              : (_isAdmitted ? 'admitted' : 'not_admitted'),
          dischargeStatus: widget.isFollowUp
              ? (_isDischarged ? 'discharged' : 'not_discharged')
              : null,
          assignedDoctorId: _selectedOtherDoctorId,
          reason: reasonText.isNotEmpty ? reasonText : null,
          notes: notesText.isNotEmpty ? notesText : null,
          temperature: tempText.isNotEmpty ? tempText : null,
          bloodPressure: bpText.isNotEmpty ? bpText : null,
          pulse: pulseText.isNotEmpty ? pulseText : null,
          spo2: spo2Text.isNotEmpty ? spo2Text : null,
          weight: weightText.isNotEmpty ? weightText : null,
          height: heightText.isNotEmpty ? heightText : null,
          diagnosis: diagnosisText,
          clinicalNotes: clinicalNotesText.isNotEmpty
              ? clinicalNotesText
              : null,
          voiceTranscript: transcriptText.isNotEmpty ? transcriptText : null,
          isFinal: _isFinal,
          medicines: finalMedicines,
          token: token,
        );

        final returnedVisitId = response['visit_id'] as int;

        final createdVisit = MockVisit(
          visitId: returnedVisitId,
          date: formattedDate,
          visitType: widget.isFollowUp ? 'Follow-up Consultation' : _visitType,
          admissionStatus: widget.isFollowUp
              ? 'Not admitted'
              : (_isAdmitted ? 'Admitted' : 'Not admitted'),
          dischargeStatus: widget.isFollowUp
              ? (_isDischarged ? 'Discharged' : 'Not discharged')
              : null,
          assignedDoctorName: _otherDoctors
              .where((doctor) => doctor.staffId == _selectedOtherDoctorId)
              .firstOrNull
              ?.name,
          doctorName: authProvider.fullName ?? 'Doctor',
          status: 'Completed',
          reason: reasonText.isNotEmpty ? reasonText : null,
          notes: notesText.isNotEmpty ? notesText : null,
        );

        final createdReport = MockReport(
          id: 'rep-$returnedVisitId',
          visitId: returnedVisitId,
          title:
              '${widget.isFollowUp ? 'Follow-up Consultation' : _visitType} Report',
          date: formattedDate,
          reportType: 'Clinical Encounter',
          summary: diagnosisText,
          diagnosis: diagnosisText,
          clinicalNotes: clinicalNotesText.isNotEmpty
              ? clinicalNotesText
              : null,
          voiceTranscript: transcriptText.isNotEmpty ? transcriptText : null,
          versionNo: 1,
          isFinal: _isFinal,
        );

        widget.onConsultationSaved(createdVisit, createdReport);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Failed to save consultation.',
            ),
            backgroundColor: saathiEmergency,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: saathiGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.medical_services_outlined,
                            color: saathiGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isFollowUp
                                  ? 'Follow-up Consultation'
                                  : 'Doctor Consultation',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: saathiNavy,
                              ),
                            ),
                            Text(
                              '${widget.patient.name} (${widget.patient.registrationNo})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: saathiBodyGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: saathiBodyGrey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: saathiLine, height: 24),

                // Step Indicators
                Row(
                  children: [
                    _buildStepTab(0, '1', 'Encounter'),
                    const SizedBox(width: 6),
                    _buildStepTab(1, '2', 'Prescription'),
                    const SizedBox(width: 6),
                    _buildStepTab(2, '3', 'Report'),
                    const SizedBox(width: 6),
                    _buildStepTab(3, '4', 'Reminders'),
                  ],
                ),
                const SizedBox(height: 20),

                // Step 1: Visit encounter details (FastAPI VisitCreate)
                if (_currentStep == 0) ...[
                  if (!widget.isFollowUp) ...[
                    const Text(
                      'Visit Type *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: saathiInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _visitType,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Consultation',
                          child: Text('Consultation (Standard)'),
                        ),
                        DropdownMenuItem(
                          value: 'Clinical Assessment',
                          child: Text('Clinical Assessment'),
                        ),
                        DropdownMenuItem(
                          value: 'Routine Checkup',
                          child: Text('Routine Checkup'),
                        ),
                        DropdownMenuItem(
                          value: 'Emergency Encounter',
                          child: Text('Emergency Encounter'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _visitType = val);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  const Text(
                    'Visit Reason',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: saathiInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _visitReasonController,
                    onTap: () => _setActiveTargetField(
                      _visitReasonController,
                      'Visit Reason',
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Routine follow-up, symptom review, elevated blood pressure',
                      prefixIcon: const Icon(Icons.help_outline),
                      suffixIcon: _fieldSuffix(_visitReasonController),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Consultation / Examination Notes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: saathiInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _visitNotesController,
                    onTap: () => _setActiveTargetField(
                      _visitNotesController,
                      'Consultation Notes',
                    ),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter clinical observations or examination summary...',
                      suffixIcon: _fieldSuffix(_visitNotesController),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Patient Vitals',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: saathiNavy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tempController,
                          onTap: () => _setActiveTargetField(
                            _tempController,
                            'Temp (°C)',
                          ),
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) =>
                              _optionalPositiveVital(value, 'temperature'),
                          decoration: InputDecoration(
                            labelText: 'Temp (°C)',
                            prefixIcon: const Icon(Icons.thermostat_outlined),
                            suffixIcon: _temperatureSuffix(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _bpController,
                          onTap: () =>
                              _setActiveTargetField(_bpController, 'BP (mmHg)'),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Blood Pressure (120/80)',
                            prefixIcon: const Icon(Icons.speed_outlined),
                            suffixIcon: _fieldSuffix(_bpController),
                          ),
                          validator: _bloodPressureValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pulseController,
                          onTap: () => _setActiveTargetField(
                            _pulseController,
                            'Pulse (bpm)',
                          ),
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) =>
                              _optionalPositiveVital(value, 'heart rate'),
                          decoration: InputDecoration(
                            labelText: 'Heart Rate (bpm)',
                            prefixIcon: const Icon(
                              Icons.favorite_border_outlined,
                            ),
                            suffixIcon: _fieldSuffix(_pulseController),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _spo2Controller,
                          onTap: () => _setActiveTargetField(
                            _spo2Controller,
                            'SpO2 (%)',
                          ),
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _spo2Validator,
                          decoration: InputDecoration(
                            labelText: 'SpO2 (%)',
                            prefixIcon: const Icon(Icons.opacity_outlined),
                            suffixIcon: _fieldSuffix(_spo2Controller),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          onTap: () => _setActiveTargetField(
                            _weightController,
                            'Weight (kg)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) =>
                              _optionalPositiveVital(value, 'weight'),
                          decoration: InputDecoration(
                            labelText: 'Weight (kg)',
                            prefixIcon: const Icon(
                              Icons.monitor_weight_outlined,
                            ),
                            suffixIcon: _fieldSuffix(_weightController),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          onTap: () => _setActiveTargetField(
                            _heightController,
                            'Height (cm)',
                          ),
                          decoration: InputDecoration(
                            labelText: 'Height (cm)',
                            prefixIcon: const Icon(Icons.height_outlined),
                            suffixIcon: _fieldSuffix(_heightController),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildVitalsWarning(),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: saathiBodyGrey),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildMicOption(),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: () => setState(() => _currentStep = 1),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Proceed to Prescription'),
                        style: FilledButton.styleFrom(
                          backgroundColor: saathiNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Step 2: Prescription Form
                if (_currentStep == 1) ...[
                  const Text(
                    'Prescribed Medicines',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: saathiNavy,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_medicines.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: saathiCream,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: saathiLine),
                      ),
                      child: const Center(
                        child: Text(
                          'No medicines added to this prescription yet.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: saathiBodyGrey,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _medicines.length,
                      itemBuilder: (context, idx) {
                        final med = _medicines[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              '${med.medicineName} (${med.medicineType})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Dosage: ${med.dosage ?? "-"} | Freq: ${med.frequency ?? "-"} | Dur: ${med.duration ?? "-"} | Notes: ${med.instructions ?? "-"}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: saathiGreen,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _editingMedIndex = idx;
                                      _medNameController.text =
                                          med.medicineName;
                                      _medType = med.medicineType ?? 'Tablet';
                                      _medDosageController.text =
                                          med.dosage ?? '';
                                      _medFreqController.text =
                                          med.frequency ?? '';
                                      _medDurationController.text =
                                          med.duration ?? '';
                                      _medInstController.text =
                                          med.instructions ?? '';
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: saathiEmergency,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _medicines.removeAt(idx);
                                      if (_editingMedIndex == idx) {
                                        _editingMedIndex = null;
                                        _medNameController.clear();
                                        _medDosageController.clear();
                                        _medFreqController.clear();
                                        _medDurationController.clear();
                                        _medInstController.clear();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const Divider(height: 24, color: saathiLine),
                  Text(
                    _editingMedIndex != null
                        ? 'Edit Medicine'
                        : 'Add New Medicine',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: saathiNavy,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _medNameController,
                    onTap: () => _setActiveTargetField(
                      _medNameController,
                      'Medicine Name',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Medicine Name *',
                      prefixIcon: const Icon(Icons.medication_outlined),
                      suffixIcon: _fieldSuffix(_medNameController),
                    ),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: _medType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'Tablet', child: Text('Tablet')),
                      DropdownMenuItem(
                        value: 'Capsule',
                        child: Text('Capsule'),
                      ),
                      DropdownMenuItem(value: 'Syrup', child: Text('Syrup')),
                      DropdownMenuItem(
                        value: 'Injection',
                        child: Text('Injection'),
                      ),
                      DropdownMenuItem(
                        value: 'Ointment',
                        child: Text('Ointment'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _medType = val);
                    },
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _medDosageController,
                          onTap: () => _setActiveTargetField(
                            _medDosageController,
                            'Dosage',
                          ),
                          decoration: InputDecoration(
                            labelText: 'Dosage (e.g. 500mg, 1 tab)',
                            suffixIcon: _fieldSuffix(_medDosageController),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _medFreqController,
                          onTap: () => _setActiveTargetField(
                            _medFreqController,
                            'Frequency',
                          ),
                          decoration: InputDecoration(
                            labelText: 'Frequency (e.g. 2x daily)',
                            suffixIcon: _fieldSuffix(_medFreqController),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _medDurationController,
                          onTap: () => _setActiveTargetField(
                            _medDurationController,
                            'Duration',
                          ),
                          decoration: InputDecoration(
                            labelText: 'Duration (e.g. 5 days)',
                            suffixIcon: _fieldSuffix(_medDurationController),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _medInstController,
                          onTap: () => _setActiveTargetField(
                            _medInstController,
                            'Instructions',
                          ),
                          decoration: InputDecoration(
                            labelText: 'Instructions (e.g. after food)',
                            suffixIcon: _fieldSuffix(_medInstController),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  FilledButton.icon(
                    onPressed: () {
                      final name = _medNameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a medicine name'),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        final item = PrescriptionItemInput(
                          medicineName: name,
                          medicineType: _medType,
                          dosage: _medDosageController.text.trim(),
                          frequency: _medFreqController.text.trim(),
                          duration: _medDurationController.text.trim(),
                          instructions: _medInstController.text.trim(),
                        );
                        if (_editingMedIndex != null) {
                          _medicines[_editingMedIndex!] = item;
                          _editingMedIndex = null;
                        } else {
                          _medicines.add(item);
                        }

                        _medNameController.clear();
                        _medDosageController.clear();
                        _medFreqController.clear();
                        _medDurationController.clear();
                        _medInstController.clear();
                        _medType = 'Tablet';
                      });
                    },
                    icon: Icon(
                      _editingMedIndex != null ? Icons.save : Icons.add,
                    ),
                    label: Text(
                      _editingMedIndex != null
                          ? 'Update Medicine'
                          : 'Add to Prescription',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: saathiGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _currentStep = 0),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back to Visit Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: saathiNavy,
                          side: const BorderSide(color: saathiLine),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      _buildMicOption(),
                      FilledButton.icon(
                        onPressed: () => setState(() => _currentStep = 2),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Proceed to Diagnosis'),
                        style: FilledButton.styleFrom(
                          backgroundColor: saathiNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Step 3: Diagnosis and Medical Report (FastAPI ReportCreate)
                if (_currentStep == 2) ...[
                  const Text(
                    'Clinical Diagnosis *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: saathiInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _diagnosisController,
                    onTap: () => _setActiveTargetField(
                      _diagnosisController,
                      'Clinical Diagnosis',
                    ),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Enter primary diagnostic assessment (required)...',
                      suffixIcon: _fieldSuffix(_diagnosisController),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Diagnosis is required to generate report';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Clinical Notes & Instructions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: saathiInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _clinicalNotesController,
                    onTap: () => _setActiveTargetField(
                      _clinicalNotesController,
                      'Clinical Notes',
                    ),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Dietary, medication, or follow-up recommendations...',
                      suffixIcon: _fieldSuffix(_clinicalNotesController),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Voice Dictation Transcript',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: saathiInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _voiceTranscriptController,
                    onTap: () => _setActiveTargetField(
                      _voiceTranscriptController,
                      'Voice Transcript',
                    ),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Dictated notes transcript (optional)...',
                      prefixIcon: const Icon(Icons.mic_none_outlined),
                      suffixIcon: _fieldSuffix(_voiceTranscriptController),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Checkbox(
                        value: _isFinal,
                        activeColor: saathiGreen,
                        onChanged: (val) =>
                            setState(() => _isFinal = val ?? true),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Mark report as Final (locked for patient record)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: saathiInk,
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      widget.isFollowUp
                          ? 'Discharge Status'
                          : 'Admission Status',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: saathiInk,
                      ),
                    ),
                    subtitle: Text(
                      widget.isFollowUp
                          ? (_isDischarged ? 'Discharged' : 'Not discharged')
                          : (_isAdmitted ? 'Admitted' : 'Not admitted'),
                    ),
                    value: widget.isFollowUp ? _isDischarged : _isAdmitted,
                    activeThumbColor: saathiGreen,
                    onChanged: (value) => setState(() {
                      if (widget.isFollowUp) {
                        _isDischarged = value;
                      } else {
                        _isAdmitted = value;
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Other Doctor Assignment',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: saathiInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedOtherDoctorId,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.medical_services_outlined),
                      hintText: _loadingOtherDoctors
                          ? 'Loading doctors…'
                          : _otherDoctors.isEmpty
                          ? 'No other doctors available'
                          : 'Select a doctor (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No additional assignment'),
                      ),
                      ..._otherDoctors.map(
                        (doctor) => DropdownMenuItem<int?>(
                          value: doctor.staffId,
                          child: Text(
                            doctor.specialization == null ||
                                    doctor.specialization!.isEmpty
                                ? doctor.name
                                : '${doctor.name} · ${doctor.specialization}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: _loadingOtherDoctors || _otherDoctors.isEmpty
                        ? null
                        : (value) =>
                              setState(() => _selectedOtherDoctorId = value),
                  ),
                  const SizedBox(height: 24),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _currentStep = 1),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back to Prescription'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: saathiNavy,
                          side: const BorderSide(color: saathiLine),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      _buildMicOption(),
                      FilledButton.icon(
                        onPressed: () {
                          if (_diagnosisController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a clinical diagnosis before proceeding',
                                ),
                                backgroundColor: saathiEmergency,
                              ),
                            );
                            return;
                          }
                          _syncMedicinesToReminders();
                          setState(() => _currentStep = 3);
                        },
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Proceed to Medicine Reminders'),
                        style: FilledButton.styleFrom(
                          backgroundColor: saathiNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Step 4: Medicine Reminders & Daily Timing
                if (_currentStep == 3) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: saathiGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.alarm_add_rounded,
                          color: saathiGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medicine Reminders & Timings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: saathiNavy,
                            ),
                          ),
                          Text(
                            'Set daily reminder times and duration dates for patient medication.',
                            style: TextStyle(
                              fontSize: 11,
                              color: saathiBodyGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Configured Reminders List
                  if (_reminders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: saathiCream,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: saathiLine),
                      ),
                      child: const Center(
                        child: Text(
                          'No medicine reminders configured yet. Set timings and date ranges below.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: saathiBodyGrey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _reminders.length,
                      itemBuilder: (context, idx) {
                        final rem = _reminders[idx];
                        final days =
                            rem.toDate.difference(rem.fromDate).inDays + 1;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: saathiLine),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: saathiMint,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            rem.medicineType,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: saathiGreen,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          rem.medicineName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: saathiNavy,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: saathiGreen,
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _editReminder(idx),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: saathiEmergency,
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            setState(() {
                                              _reminders.removeAt(idx);
                                              if (_editingReminderIndex ==
                                                  idx) {
                                                _editingReminderIndex = null;
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Date range row
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: saathiCream,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: saathiLine),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.date_range,
                                        size: 15,
                                        color: saathiGreen,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'From: ${_formatDate(rem.fromDate)}  ➔  To: ${_formatDate(rem.toDate)} ($days ${days == 1 ? "day" : "days"})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: saathiNavy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Times chips & food info
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    ...rem.reminderTimes.map(
                                      (t) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: saathiGreen.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: saathiGreen.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              size: 13,
                                              color: saathiGreen,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatTime(t),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: saathiGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: saathiAmber.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '🍽️ ${rem.mealTiming} • ${rem.dosage}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                    if (rem.instructions.isNotEmpty)
                                      Text(
                                        '(${rem.instructions})',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: saathiBodyGrey,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const Divider(height: 24, color: saathiLine),

                  // Form Section Title
                  Text(
                    _editingReminderIndex != null
                        ? 'Edit Medicine Reminder Schedule'
                        : 'Add / Configure Medicine Reminder',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: saathiNavy,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Medicine Selector
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value:
                              (_selectedReminderMedName != null &&
                                  (_medicines.any(
                                        (m) =>
                                            m.medicineName ==
                                            _selectedReminderMedName,
                                      ) ||
                                      _reminders.any(
                                        (r) =>
                                            r.medicineName ==
                                            _selectedReminderMedName,
                                      )))
                              ? _selectedReminderMedName
                              : '+ Other Custom Medicine...',
                          decoration: const InputDecoration(
                            labelText: 'Select Medicine *',
                            prefixIcon: Icon(Icons.medication_outlined),
                          ),
                          items: [
                            ...{
                              ..._medicines.map((m) => m.medicineName),
                              ..._reminders.map((r) => r.medicineName),
                            }.map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              ),
                            ),
                            const DropdownMenuItem(
                              value: '+ Other Custom Medicine...',
                              child: Text('+ Other Custom Medicine...'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedReminderMedName = val;
                                final match = _medicines
                                    .where((m) => m.medicineName == val)
                                    .firstOrNull;
                                if (match != null) {
                                  _reminderMedType =
                                      match.medicineType ?? 'Tablet';
                                  if (match.dosage != null &&
                                      match.dosage!.isNotEmpty) {
                                    _reminderDosageController.text =
                                        match.dosage!;
                                  }
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _reminderMedType,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(
                              value: 'Tablet',
                              child: Text('Tablet'),
                            ),
                            DropdownMenuItem(
                              value: 'Capsule',
                              child: Text('Capsule'),
                            ),
                            DropdownMenuItem(
                              value: 'Syrup',
                              child: Text('Syrup'),
                            ),
                            DropdownMenuItem(
                              value: 'Injection',
                              child: Text('Injection'),
                            ),
                            DropdownMenuItem(
                              value: 'Ointment',
                              child: Text('Ointment'),
                            ),
                            DropdownMenuItem(
                              value: 'Drops',
                              child: Text('Drops'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _reminderMedType = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_selectedReminderMedName ==
                          '+ Other Custom Medicine...' ||
                      _selectedReminderMedName == null) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _reminderCustomMedController,
                      decoration: const InputDecoration(
                        labelText: 'Custom Medicine Name *',
                        hintText: 'Enter medicine name...',
                        prefixIcon: Icon(Icons.medication_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // From and To Date Pickers
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickFromDate,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'From Date (Start) *',
                              prefixIcon: Icon(Icons.calendar_month_outlined),
                            ),
                            child: Text(
                              _formatDate(_reminderFromDate),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: saathiInk,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _pickToDate,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'To Date (End) *',
                              prefixIcon: Icon(Icons.event_available_outlined),
                            ),
                            child: Text(
                              _formatDate(_reminderToDate),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: saathiInk,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Daily Reminder Times
                  const Text(
                    'Daily Reminder Times *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: saathiInk,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Quick presets
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(
                          Icons.wb_sunny_outlined,
                          size: 14,
                          color: saathiGreen,
                        ),
                        label: const Text('Morning (08:00 AM)'),
                        backgroundColor:
                            _currentReminderTimes.any(
                              (t) => t.hour == 8 && t.minute == 0,
                            )
                            ? saathiMint
                            : saathiCream,
                        side: BorderSide(
                          color:
                              _currentReminderTimes.any(
                                (t) => t.hour == 8 && t.minute == 0,
                              )
                              ? saathiGreen
                              : saathiLine,
                        ),
                        onPressed: () => _togglePresetTime(
                          const TimeOfDay(hour: 8, minute: 0),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.wb_twilight_outlined,
                          size: 14,
                          color: saathiGreen,
                        ),
                        label: const Text('Afternoon (01:00 PM)'),
                        backgroundColor:
                            _currentReminderTimes.any(
                              (t) => t.hour == 13 && t.minute == 0,
                            )
                            ? saathiMint
                            : saathiCream,
                        side: BorderSide(
                          color:
                              _currentReminderTimes.any(
                                (t) => t.hour == 13 && t.minute == 0,
                              )
                              ? saathiGreen
                              : saathiLine,
                        ),
                        onPressed: () => _togglePresetTime(
                          const TimeOfDay(hour: 13, minute: 0),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.wb_sunny,
                          size: 14,
                          color: saathiGreen,
                        ),
                        label: const Text('Evening (06:00 PM)'),
                        backgroundColor:
                            _currentReminderTimes.any(
                              (t) => t.hour == 18 && t.minute == 0,
                            )
                            ? saathiMint
                            : saathiCream,
                        side: BorderSide(
                          color:
                              _currentReminderTimes.any(
                                (t) => t.hour == 18 && t.minute == 0,
                              )
                              ? saathiGreen
                              : saathiLine,
                        ),
                        onPressed: () => _togglePresetTime(
                          const TimeOfDay(hour: 18, minute: 0),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.nightlight_outlined,
                          size: 14,
                          color: saathiGreen,
                        ),
                        label: const Text('Night (09:00 PM)'),
                        backgroundColor:
                            _currentReminderTimes.any(
                              (t) => t.hour == 21 && t.minute == 0,
                            )
                            ? saathiMint
                            : saathiCream,
                        side: BorderSide(
                          color:
                              _currentReminderTimes.any(
                                (t) => t.hour == 21 && t.minute == 0,
                              )
                              ? saathiGreen
                              : saathiLine,
                        ),
                        onPressed: () => _togglePresetTime(
                          const TimeOfDay(hour: 21, minute: 0),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.add_alarm,
                          size: 14,
                          color: saathiNavy,
                        ),
                        label: const Text('+ Custom Time'),
                        backgroundColor: saathiCream,
                        side: const BorderSide(color: saathiLine),
                        onPressed: _pickCustomTime,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Selected times chips
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: saathiCream,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: saathiLine),
                    ),
                    child: _currentReminderTimes.isEmpty
                        ? const Text(
                            'No reminder times selected. Tap a preset above or add a custom time.',
                            style: TextStyle(
                              fontSize: 12,
                              color: saathiEmergency,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _currentReminderTimes
                                .map(
                                  (tod) => Chip(
                                    avatar: const Icon(
                                      Icons.alarm,
                                      size: 16,
                                      color: saathiGreen,
                                    ),
                                    label: Text(
                                      _formatTime(tod),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: saathiNavy,
                                      ),
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 16,
                                    ),
                                    onDeleted: () {
                                      setState(() {
                                        _currentReminderTimes.remove(tod);
                                      });
                                    },
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: saathiLine),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Meal Timing & Dosage
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _reminderMealTiming,
                          decoration: const InputDecoration(
                            labelText: 'Meal Timing',
                            prefixIcon: Icon(Icons.restaurant_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'After Food',
                              child: Text('After Food'),
                            ),
                            DropdownMenuItem(
                              value: 'Before Food',
                              child: Text('Before Food'),
                            ),
                            DropdownMenuItem(
                              value: 'With Food',
                              child: Text('With Food'),
                            ),
                            DropdownMenuItem(
                              value: 'Empty Stomach',
                              child: Text('Empty Stomach'),
                            ),
                            DropdownMenuItem(
                              value: 'Anytime / As Needed',
                              child: Text('Anytime / As Needed'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _reminderMealTiming = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _reminderDosageController,
                          decoration: const InputDecoration(
                            labelText: 'Dosage',
                            hintText: 'e.g. 1 tablet, 5ml',
                            prefixIcon: Icon(Icons.straighten_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Optional instructions
                  TextFormField(
                    controller: _reminderInstController,
                    decoration: const InputDecoration(
                      labelText: 'Special Reminder Instructions (Optional)',
                      hintText: 'e.g. Take with warm water, avoid milk, after dinner...',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Add / Update Reminder Button
                  FilledButton.icon(
                    onPressed: _saveOrUpdateReminder,
                    icon: Icon(
                      _editingReminderIndex != null
                          ? Icons.check
                          : Icons.add_alarm_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _editingReminderIndex != null
                          ? 'Update Reminder Schedule'
                          : 'Add / Save Reminder Schedule',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: saathiGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer navigation for Step 4
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _currentStep = 2),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back to Report'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: saathiNavy,
                          side: const BorderSide(color: saathiLine),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      _buildMicOption(),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveConsultation,
                        icon: _isSaving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 16),
                        label: const Text('Save & Finalize Consultation'),
                        style: FilledButton.styleFrom(
                          backgroundColor: saathiGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
