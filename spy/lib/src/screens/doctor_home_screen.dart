import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import '../notification_provider.dart';
import '../theme.dart';
import 'role_select_screen.dart';
import 'doctor_dashboard_screen.dart';
import 'doctor_patients_screen.dart';
import '../widgets/watermark_background.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _currentIndex = 0;
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  void _startNotificationPolling() {
    _sync();
    _notifTimer = Timer.periodic(const Duration(seconds: 3), (_) => _sync());
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final notif = Provider.of<NotificationProvider>(context, listen: false);
    if (auth.token != null && !auth.useMockApi) {
      await notif.fetchNotifications(apiClient: auth.apiClient, token: auth.token!);
    }
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  void _showSignOutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.bold, color: saathiNavy),
        ),
        content: const Text('Are you sure you want to sign out of the Doctor Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: saathiBodyGrey)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const RoleSelectScreen()),
                  (route) => false,
                );
              }
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: saathiEmergency,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final doctorName = authProvider.fullName?.isNotEmpty == true
        ? authProvider.fullName!
        : 'Dr. Sharma';

    final List<Widget> pages = [
      DoctorDashboardScreen(onNavigateToTab: _onTabSelected),
      const DoctorPatientsScreen(),
    ];

    final activeIndex = _currentIndex >= pages.length ? 0 : _currentIndex;

    return Scaffold(
      backgroundColor: saathiCream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          if (isNarrow) {
            // Mobile fallback
            return Column(
              children: [
                AppBar(
                  title: Row(
                    children: [
                      Image.asset(
                        'assets/images/saathi_logo.png',
                        height: 32,
                        width: 32,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      const Text('Doctor Portal'),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => _showSignOutDialog(context, authProvider),
                    ),
                  ],
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

          // Desktop Sidebar Shell
          return Row(
            children: [
              _DoctorDesktopSidebar(
                currentIndex: activeIndex,
                onTap: _onTabSelected,
                doctorName: doctorName,
                onSignOut: () => _showSignOutDialog(context, authProvider),
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
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 600
          ? NavigationBar(
              selectedIndex: activeIndex,
              onDestinationSelected: _onTabSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Patients',
                ),
              ],
            )
          : null,
    );
  }
}

class _DoctorDesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String doctorName;
  final VoidCallback onSignOut;

  const _DoctorDesktopSidebar({
    required this.currentIndex,
    required this.onTap,
    required this.doctorName,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: saathiCream,
        border: Border(
          right: BorderSide(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branding Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/saathi_logo.png',
                  height: 38,
                  width: 38,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saathi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: saathiNavy,
                      ),
                    ),
                    Text(
                      'DOCTOR PORTAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: saathiGreen,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: saathiLine),
          const SizedBox(height: 12),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(
                  context,
                  index: 0,
                  label: 'Dashboard',
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  context,
                  index: 1,
                  label: 'My Patients',
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                ),
              ],
            ),
          ),

          // Bottom Doctor Identity & Sign out
          const Divider(height: 1, color: saathiLine),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: saathiLine),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: saathiGreen.withValues(alpha: 0.15),
                    child: Text(
                      doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: saathiGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: saathiNavy,
                          ),
                        ),
                        const Text(
                          'Doctor',
                          style: TextStyle(
                            fontSize: 11,
                            color: saathiBodyGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 18, color: saathiBodyGrey),
                    tooltip: 'Sign Out',
                    onPressed: onSignOut,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? saathiGreen.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 20,
                color: isSelected ? saathiGreen : saathiNavy.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? saathiGreen : saathiNavy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
