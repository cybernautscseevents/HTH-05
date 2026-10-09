import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_provider.dart';
import '../notification_provider.dart';
import '../theme.dart';
import '../api_client.dart';
import '../widgets/digital_clock_widget.dart';
import '../widgets/page_header.dart';
import '../widgets/patient_table_view.dart';
import 'patient_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onNavigateToTab,
    this.onRegisterPatient,
    this.refreshSignal = 0,
  });

  final ValueChanged<int> onNavigateToTab;
  final VoidCallback? onRegisterPatient;
  final int refreshSignal;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int? _totalPatientsCount;
  int? _activeDevicesCount;
  int? _registeredTodayCount;
  int? _pendingSetupCount;
  List<PatientSearchResult> _recentPatients = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.useMockApi) {
      final stats = await authProvider.mockApiClient.getDashboardStats();
      final recent = await authProvider.mockApiClient.getRecentPatients();
      if (mounted) {
        setState(() {
          _totalPatientsCount = stats['totalPatients'] as int?;
          _activeDevicesCount = stats['activeDevices'] as int?;
          _registeredTodayCount = stats['registeredToday'] as int?;
          _pendingSetupCount = stats['pendingSetup'] as int?;
          _recentPatients = recent;
          _isLoading = false;
        });
      }
    } else {
      try {
        final token = authProvider.token;
        if (token == null) throw ApiException('Session expired.');
        final stats = await authProvider.apiClient.getDashboardStats(token);
        final List recentList = stats['recent_patients'] as List;
        final recent = recentList
            .map((j) => PatientSearchResult.fromJson(j as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _totalPatientsCount = stats['total_patients'] as int?;
            _activeDevicesCount = stats['active_devices'] as int?;
            _registeredTodayCount = stats['registered_today'] as int?;
            _pendingSetupCount = stats['pending_setup'] as int?;
            _recentPatients = recent;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final role = authProvider.role ?? 'Staff';

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: saathiGreen,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            PageHeader(
              title:
                  'Welcome back, ${role[0].toUpperCase()}${role.substring(1)}',
              subtitle: 'Hospital Staff Portal Overview & Operations',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DigitalClockWidget(),
                  const SizedBox(width: 12),
                  _buildNotificationBell(context),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Refresh dashboard',
                    child: IconButton.filledTonal(
                      onPressed: _isLoading ? null : _loadDashboardData,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                  ),
                ],
              ),
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
              ),

            if (!_isLoading) ...[
              // Operational Metrics Strip (Hospital Grade)
              _buildMetricsStrip(),
              const SizedBox(height: 20),

              // Quick Operations Toolbar
              _buildOperationsToolbar(),
              const SizedBox(height: 24),

              Expanded(child: _buildRecentPatientsSection()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notifications, _) => Stack(
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
              tooltip: 'Notifications',
              icon: Icon(
                notifications.hasUnread
                    ? Icons.notifications_active
                    : Icons.notifications_none_outlined,
                color: notifications.hasUnread ? saathiGreen : saathiNavy,
              ),
              onPressed: () => _showNotificationsPanel(context),
            ),
          ),
          if (notifications.hasUnread)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: const BoxDecoration(
                  color: saathiEmergency,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  notifications.unreadCount > 9
                      ? '9+'
                      : '${notifications.unreadCount}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showNotificationsPanel(BuildContext dashboardContext) {
    final auth = Provider.of<AuthProvider>(dashboardContext, listen: false);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogContext) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 80, right: 32),
          child: Material(
            borderRadius: BorderRadius.circular(16),
            elevation: 12,
            child: Consumer<NotificationProvider>(
              builder: (context, notifications, _) => Container(
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: saathiCream,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active,
                            color: saathiGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Notifications (${notifications.unreadCount})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: saathiNavy,
                              ),
                            ),
                          ),
                          if (notifications.hasUnread)
                            TextButton(
                              onPressed: () => notifications.markAllAsRead(
                                apiClient: auth.apiClient,
                                token: auth.token,
                              ),
                              child: const Text('Mark all read'),
                            ),
                          IconButton(
                            tooltip: 'Close',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),
                    if (notifications.notifications.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              color: saathiBodyGrey,
                              size: 40,
                            ),
                            SizedBox(height: 10),
                            Text('No notifications yet'),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: notifications.notifications.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = notifications.notifications[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                item.type == 'admission'
                                    ? Icons.local_hospital_outlined
                                    : Icons.notifications_active_outlined,
                                color: item.isRead
                                    ? saathiBodyGrey
                                    : saathiGreen,
                              ),
                              title: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.isRead
                                      ? FontWeight.normal
                                      : FontWeight.w700,
                                ),
                              ),
                              subtitle: Text('${item.body}\n${item.timestamp}'),
                              isThreeLine: true,
                              onTap: () {
                                notifications.markAsRead(
                                  item.id,
                                  apiClient: auth.apiClient,
                                  token: auth.token,
                                );
                                final metadata = item.metadata ?? const {};
                                final patientId = int.tryParse(
                                  metadata['patient_id']?.toString() ?? '',
                                );
                                if (item.type != 'admission' ||
                                    patientId == null) {
                                  return;
                                }
                                Navigator.pop(dialogContext);
                                Navigator.of(dashboardContext).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PatientProfileScreen(
                                      patient: PatientSearchResult(
                                        patientId: patientId,
                                        registrationNo:
                                            metadata['registration_no']
                                                ?.toString() ??
                                            '',
                                        name:
                                            metadata['patient_name']
                                                ?.toString() ??
                                            'Patient',
                                      ),
                                      openAdmissionOnLoad: true,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsStrip() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        final items = [
          _MetricItem(
            title: 'Total Patients',
            value: _totalPatientsCount != null ? '$_totalPatientsCount' : '—',
            icon: Icons.people_alt_outlined,
            color: saathiNavy,
          ),
          _MetricItem(
            title: 'Active Devices',
            value: _activeDevicesCount != null ? '$_activeDevicesCount' : '—',
            icon: Icons.phonelink_ring_outlined,
            color: saathiGreen,
          ),
          _MetricItem(
            title: 'Registered Today',
            value: _registeredTodayCount != null
                ? '$_registeredTodayCount'
                : '—',
            icon: Icons.person_add_alt_1_outlined,
            color: saathiTeal,
          ),
          _MetricItem(
            title: 'Pending Setup',
            value: _pendingSetupCount != null ? '$_pendingSetupCount' : '—',
            icon: Icons.pending_actions_outlined,
            color: saathiAmber,
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

  Widget _buildRecentPatientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              icon: const Icon(Icons.arrow_forward, size: 15),
              label: const Text(
                'View All',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => PatientTableView(
              patients: _recentPatients,
              // The header is fixed above the scrolling rows; reserve enough
              // room for its vertical padding and the enclosing border.
              scrollViewportHeight: (constraints.maxHeight - 60).clamp(
                0.0,
                800.0,
              ),
              onPatientSelected: (patient) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PatientProfileScreen(patient: patient),
                  ),
                );
              },
              emptyMessage: 'No recent patient records available.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationsToolbar() {
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
            'Quick Operations',
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
              _buildActionButton(
                label: 'Register Patient',
                icon: Icons.person_add_outlined,
                color: saathiGreen,
                isPrimary: true,
                onTap:
                    widget.onRegisterPatient ?? () => widget.onNavigateToTab(1),
              ),
              _buildActionButton(
                label: 'Search Patients',
                icon: Icons.search,
                color: saathiNavy,
                isPrimary: false,
                onTap: () => widget.onNavigateToTab(1),
              ),
              _buildActionButton(
                label: 'Manage Devices',
                icon: Icons.devices_outlined,
                color: saathiTeal,
                isPrimary: false,
                onTap: () => widget.onNavigateToTab(2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    if (isPrimary) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 38),
          backgroundColor: saathiGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        foregroundColor: saathiNavy,
        side: const BorderSide(color: saathiLine),
        backgroundColor: saathiCream,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MetricItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
