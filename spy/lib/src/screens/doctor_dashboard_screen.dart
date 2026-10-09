import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../auth_provider.dart';
import '../notification_provider.dart';
import '../theme.dart';
import '../widgets/digital_clock_widget.dart';
import '../widgets/page_header.dart';
import '../widgets/patient_table_view.dart';
import 'doctor_patient_profile_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateToTab;

  const DoctorDashboardScreen({super.key, required this.onNavigateToTab});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  bool _isLoading = true;
  bool _hasDashboardData = false;
  String? _dashboardError;
  int? _myPatientsCount;
  int? _todaysVisitsCount;
  int? _pendingReportsCount;
  List<PatientSearchResult> _recentPatients = [];
  List<PendingReportItem> _pendingReportsList = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startNotificationPolling() {
    _syncNotifications();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _syncNotifications();
    });
  }

  Future<void> _syncNotifications() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notifProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );
    final token = authProvider.token;
    if (token == null || authProvider.useMockApi) return;

    final prevCount = notifProvider.notifications.length;
    final prevUnread = notifProvider.unreadCount;

    final hasNew = await notifProvider.fetchNotifications(
      apiClient: authProvider.apiClient,
      token: token,
    );

    if (hasNew ||
        notifProvider.notifications.length > prevCount ||
        notifProvider.unreadCount > prevUnread) {
      if (mounted) {
        _loadDashboardData(isBackgroundSync: true);
      }
    }
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  Future<void> _loadDashboardData({bool isBackgroundSync = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      if (!isBackgroundSync && mounted && !_hasDashboardData) {
        setState(() => _isLoading = true);
      }
      if (authProvider.useMockApi) {
        final recent = await authProvider.mockApiClient
            .getDoctorRecentPatients();
        if (mounted) {
          setState(() {
            _myPatientsCount = 12;
            _todaysVisitsCount = 3;
            _pendingReportsCount = 1;
            _recentPatients = recent;
            _pendingReportsList = [
              PendingReportItem(
                reportId: 101,
                patientId: 1,
                patientName: 'Anita Roy',
                registrationNo: 'MA-2026-000001',
                visitId: 50,
                diagnosis: 'Hypertension Follow-up (Draft)',
                clinicalNotes: 'Awaiting lab reports before sign-off',
                reportDatetime: '2026-08-24 10:30',
                isFinal: false,
              ),
            ];
            _hasDashboardData = true;
            _dashboardError = null;
            _isLoading = false;
          });
        }
      } else {
        final token = authProvider.token;
        if (token == null) throw ApiException('Session expired.');
        final stats = await authProvider.apiClient.getDashboardStats(token);
        final List recentList = stats['recent_patients'] as List;
        final recent = recentList
            .map((j) => PatientSearchResult.fromJson(j as Map<String, dynamic>))
            .toList();

        final List pendingListRaw =
            (stats['pending_reports_list'] as List?) ?? [];
        final pendingList = pendingListRaw
            .map((j) => PendingReportItem.fromJson(j as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            _myPatientsCount = stats['my_patients'] as int?;
            _todaysVisitsCount = stats['todays_visits'] as int?;
            _pendingReportsCount = stats['pending_reports'] as int?;
            _recentPatients = recent;
            _pendingReportsList = pendingList;
            _hasDashboardData = true;
            _dashboardError = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[DoctorDashboardScreen] Failed to load dashboard stats: $e');
      if (mounted) {
        setState(() {
          _dashboardError = 'Dashboard data could not be loaded. Please retry.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _finalizeReport(PendingReportItem report) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null && !authProvider.useMockApi) return;
    try {
      if (!authProvider.useMockApi) {
        await authProvider.apiClient.finalizeReport(
          report.reportId,
          token: authProvider.token!,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report for ${report.patientName} finalized successfully.',
            ),
          ),
        );
      }
      await _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to finalize report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final doctorName = authProvider.fullName?.isNotEmpty == true
        ? authProvider.fullName!
        : 'Dr. Sharma';

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: saathiGreen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompactHeight = constraints.maxHeight < 620;

          Widget buildDashboardContent(bool useExpanded) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header with Notification Bell, Digital Clock, and Refresh Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: PageHeader(
                        title: '${_getTimeGreeting()}, $doctorName',
                        subtitle: "Here's your clinical overview.",
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildRefreshButton(),
                    const SizedBox(width: 12),
                    const DigitalClockWidget(),
                    const SizedBox(width: 12),
                    _buildNotificationBell(context),
                  ],
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: saathiGreen),
                      ),
                    ),
                  )
                else if (_dashboardError != null && !_hasDashboardData) ...[
                  _buildDashboardError(),
                ] else ...[
                  if (_dashboardError != null) ...[
                    _buildDashboardError(),
                    const SizedBox(height: 18),
                  ],
                  // Operational Metrics Strip (Hospital Grade)
                  _buildMetricsStrip(),
                  const SizedBox(height: 18),

                  // Pending Reports Card / Section
                  if (_pendingReportsList.isNotEmpty) ...[
                    _buildPendingReportsSection(),
                    const SizedBox(height: 18),
                  ],

                  // Quick Actions Toolbar
                  _buildClinicalToolbar(),
                  const SizedBox(height: 18),

                  // Recent Patients Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Recent Patients',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: saathiNavy,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => widget.onNavigateToTab(1),
                        style: TextButton.styleFrom(
                          foregroundColor: saathiTeal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward, size: 15),
                        label: const Text(
                          'View All',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Hospital Table: Table header remains fixed, only rows scroll
                  if (useExpanded)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, tableConstraints) =>
                            PatientTableView(
                              patients: _recentPatients,
                              scrollViewportHeight:
                                  // Keep the fixed header and border within the
                                  // available column height on shorter screens.
                                  (tableConstraints.maxHeight - 60).clamp(
                                    0.0,
                                    1400.0,
                                  ),
                              onPatientSelected: (patient) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        DoctorPatientProfileScreen(
                                          patient: patient,
                                        ),
                                  ),
                                );
                              },
                              emptyMessage:
                                  'No recent patient records available.',
                            ),
                      ),
                    )
                  else
                    PatientTableView(
                      patients: _recentPatients,
                      scrollViewportHeight: 350,
                      onPatientSelected: (patient) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DoctorPatientProfileScreen(patient: patient),
                          ),
                        );
                      },
                      emptyMessage: 'No recent patient records available.',
                    ),
                ],
              ],
            );
          }

          if (isCompactHeight) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: buildDashboardContent(false),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: buildDashboardContent(true),
          );
        },
      ),
    );
  }

  Widget _buildDashboardError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: saathiEmergencyTint,
        border: Border.all(color: saathiEmergency),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: saathiEmergency),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _dashboardError!,
              style: const TextStyle(color: saathiNavy),
            ),
          ),
          TextButton(onPressed: _loadDashboardData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildPendingReportsSection() {
    return Container(
      decoration: BoxDecoration(
        color: saathiEmergencyTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: saathiAmber.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_late_outlined,
                color: saathiAmber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Pending Clinical Reports (${_pendingReportsList.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: saathiNavy,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: saathiAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Requires Review',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: saathiAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingReportsList.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 16, color: saathiLine),
            itemBuilder: (context, index) {
              final report = _pendingReportsList[index];
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${report.patientName} (${report.registrationNo})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: saathiNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Diagnosis: ${report.diagnosis.isNotEmpty ? report.diagnosis : "Pending Diagnosis"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: saathiInk,
                          ),
                        ),
                        if (report.clinicalNotes?.isNotEmpty == true)
                          Text(
                            'Notes: ${report.clinicalNotes}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: saathiBodyGrey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _finalizeReport(report),
                    icon: const Icon(Icons.check_circle_outline, size: 15),
                    label: const Text('Finalize'),
                    style: FilledButton.styleFrom(
                      backgroundColor: saathiGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      minimumSize: const Size(0, 34),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsStrip() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        final items = [
          _DoctorMetricItem(
            title: 'My Patients',
            value: _myPatientsCount != null ? '$_myPatientsCount' : '—',
            icon: Icons.people_alt_outlined,
            color: saathiNavy,
          ),
          _DoctorMetricItem(
            title: "Today's Visits",
            value: _todaysVisitsCount != null ? '$_todaysVisitsCount' : '—',
            icon: Icons.calendar_today_outlined,
            color: saathiGreen,
          ),
          _DoctorMetricItem(
            title: 'Pending Reports',
            value: _pendingReportsCount != null ? '$_pendingReportsCount' : '—',
            icon: Icons.assignment_outlined,
            color: saathiAmber,
          ),
          _DoctorMetricItem(
            title: 'Recent Patients',
            value: '${_recentPatients.length}',
            icon: Icons.history_outlined,
            color: saathiTeal,
          ),
        ];

        if (isWide) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: saathiLine),
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: index < items.length - 1
                          ? const Border(right: BorderSide(color: saathiLine))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon, color: item.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.value,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: item.color,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: saathiBodyGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }

        // 2x2 Grid for smaller screens
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.3,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: saathiLine),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(item.icon, color: item.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.value,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: item.color,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          item.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: saathiBodyGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClinicalToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: saathiLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: saathiBodyGrey,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => widget.onNavigateToTab(1),
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('My Patients'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  backgroundColor: saathiNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onNavigateToTab(1),
                icon: const Icon(Icons.search, size: 16, color: saathiTeal),
                label: const Text('Search Patients'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  foregroundColor: saathiNavy,
                  side: const BorderSide(color: saathiLine),
                  backgroundColor: saathiCream,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: saathiLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        tooltip: 'Refresh dashboard',
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: saathiGreen,
                ),
              )
            : const Icon(Icons.refresh_rounded, color: saathiNavy, size: 22),
        onPressed: _isLoading ? null : () => _loadDashboardData(),
      ),
    );
  }

  // ── Notification Bell Widget ──────────────────────────────────────────────

  Widget _buildNotificationBell(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notifProvider, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: saathiLine),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  notifProvider.hasUnread
                      ? Icons.notifications_active
                      : Icons.notifications_none_outlined,
                  color: notifProvider.hasUnread ? saathiGreen : saathiNavy,
                  size: 24,
                ),
                tooltip: 'Notifications',
                onPressed: () =>
                    _showNotificationsPanel(context, notifProvider),
              ),
            ),
            if (notifProvider.hasUnread)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: saathiEmergency,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    notifProvider.unreadCount > 9
                        ? '9+'
                        : notifProvider.unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsPanel(
    BuildContext context,
    NotificationProvider notifProvider,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 80, right: 32),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              elevation: 12,
              child: Container(
                width: 380,
                constraints: const BoxConstraints(maxHeight: 480),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: saathiLine),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: saathiCream,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.notifications_active,
                                color: saathiGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Notifications (${notifProvider.unreadCount})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: saathiNavy,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (notifProvider.hasUnread)
                                TextButton(
                                  onPressed: () {
                                    final authProvider =
                                        Provider.of<AuthProvider>(
                                          context,
                                          listen: false,
                                        );
                                    notifProvider.markAllAsRead(
                                      apiClient: authProvider.apiClient,
                                      token: authProvider.token,
                                    );
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text(
                                    'Mark all read',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: saathiTeal,
                                    ),
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: saathiBodyGrey,
                                ),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Notification List
                    if (notifProvider.notifications.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              color: saathiBodyGrey,
                              size: 40,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No notifications yet',
                              style: TextStyle(
                                color: saathiBodyGrey,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You\'ll be notified when patients are registered.',
                              style: TextStyle(
                                color: saathiBodyGrey,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: notifProvider.notifications.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: saathiLine),
                          itemBuilder: (context, index) {
                            final notif = notifProvider.notifications[index];
                            return InkWell(
                              onTap: () {
                                final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );
                                notifProvider.markAsRead(
                                  notif.id,
                                  apiClient: authProvider.apiClient,
                                  token: authProvider.token,
                                );
                                Navigator.pop(ctx);
                                final rawPid = notif.metadata?['patient_id'];
                                final pid = rawPid is int
                                    ? rawPid
                                    : int.tryParse(rawPid?.toString() ?? '');
                                if (pid != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DoctorPatientProfileScreen(
                                        patient: PatientSearchResult(
                                          patientId: pid,
                                          registrationNo:
                                              notif.metadata?['registration_no']
                                                  ?.toString() ??
                                              'N/A',
                                          name:
                                              notif.metadata?['patient_name']
                                                  ?.toString() ??
                                              'Patient',
                                          diseaseCondition: notif
                                              .metadata?['condition']
                                              ?.toString(),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                color: notif.isRead
                                    ? Colors.white
                                    : saathiMint.withValues(alpha: 0.3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            notif.type == 'patient_registered'
                                            ? saathiGreen.withValues(
                                                alpha: 0.12,
                                              )
                                            : saathiCream,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        notif.type == 'patient_registered'
                                            ? Icons.person_add
                                            : Icons.info_outline,
                                        color:
                                            notif.type == 'patient_registered'
                                            ? saathiGreen
                                            : saathiNavy,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notif.title,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: notif.isRead
                                                        ? FontWeight.w500
                                                        : FontWeight.bold,
                                                    color: saathiNavy,
                                                  ),
                                                ),
                                              ),
                                              if (!notif.isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: saathiGreen,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notif.body,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: saathiInk,
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notif.timestamp,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: saathiBodyGrey,
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
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DoctorMetricItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DoctorMetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
