import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_provider.dart';
import '../theme.dart';
import '../widgets/desktop_sidebar.dart';
import '../widgets/watermark_background.dart';
import 'dashboard_screen.dart';
import 'receptionist_home_screen.dart';
import 'search_patients_screen.dart';
import 'manage_devices_screen.dart';
import 'admin_staff_management_screen.dart';

class StaffShell extends StatefulWidget {
  const StaffShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  late int _currentIndex;
  int _dashboardRefreshSignal = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openRegisterModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: saathiCream,
        child: Container(
          width: 550,
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              RegisterPatientView(
                onRegistered: _refreshDashboard,
                onExitToDashboard: () {
                  Navigator.of(context).pop();
                  _onTabSelected(0);
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refreshDashboard() {
    if (mounted) setState(() => _dashboardRefreshSignal++);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final role = authProvider.role?.toLowerCase() ?? 'receptionist';
    final isAdmin = role == 'admin';

    final List<Widget> pages = [
      DashboardScreen(
        onNavigateToTab: _onTabSelected,
        onRegisterPatient: () => _openRegisterModal(context),
        refreshSignal: _dashboardRefreshSignal,
      ),
      PatientsTabContainer(
        onPatientRegistered: _refreshDashboard,
        onExitToDashboard: () => _onTabSelected(0),
      ),
      const ManageDevicesScreen(),
      if (isAdmin) const StaffAccountsView(),
    ];

    final activeIndex = _currentIndex >= pages.length ? 0 : _currentIndex;

    return Scaffold(
      backgroundColor: saathiCream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          if (isNarrow) {
            // Mobile layout fallback with bottom navigation bar
            return Column(
              children: [
                AppBar(
                  title: Row(
                    children: [
                      Image.asset(
                        'assets/images/saathi_logo.png',
                        height: 32,
                        width: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(isAdmin ? 'Saathi Admin' : 'Saathi Staff'),
                    ],
                  ),
                ),
                Expanded(
                  child: WatermarkBackground(
                    opacity: kHospitalWorkingWatermarkOpacity,
                    spacing: kHospitalWorkingWatermarkSpacing,
                    child: pages[activeIndex],
                  ),
                ),
              ],
            );
          }

          // Desktop / Tablet layout with Custom Sidebar
          return Row(
            children: [
              DesktopSidebar(currentIndex: activeIndex, onTap: _onTabSelected),
              Expanded(
                child: WatermarkBackground(
                  opacity: kHospitalWorkingWatermarkOpacity,
                  spacing: kHospitalWorkingWatermarkSpacing,
                  child: pages[activeIndex],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) return const SizedBox.shrink();

          return BottomNavigationBar(
            currentIndex: activeIndex,
            selectedItemColor: saathiGreen,
            unselectedItemColor: saathiBodyGrey,
            backgroundColor: Colors.white,
            onTap: _onTabSelected,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: 'Patients',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.devices_outlined),
                activeIcon: Icon(Icons.devices),
                label: 'Devices',
              ),
              if (isAdmin)
                const BottomNavigationBarItem(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  activeIcon: Icon(Icons.admin_panel_settings),
                  label: 'Staff',
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Tab container combining Search and Register ────────────────────────────

class PatientsTabContainer extends StatefulWidget {
  const PatientsTabContainer({
    super.key,
    this.onPatientRegistered,
    this.onExitToDashboard,
  });

  final VoidCallback? onPatientRegistered;
  final VoidCallback? onExitToDashboard;

  @override
  State<PatientsTabContainer> createState() => _PatientsTabContainerState();
}

class _PatientsTabContainerState extends State<PatientsTabContainer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: saathiCream,
          child: TabBar(
            controller: _tabController,
            labelColor: saathiGreen,
            unselectedLabelColor: saathiBodyGrey,
            indicatorColor: saathiGreen,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'All Patients'),
              Tab(icon: Icon(Icons.person_add), text: 'Register Patient'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              const SearchPatientsScreen(),
              RegisterPatientView(
                onRegistered: widget.onPatientRegistered,
                onExitToDashboard: widget.onExitToDashboard,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
