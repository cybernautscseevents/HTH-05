import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import '../theme.dart';
import '../screens/role_select_screen.dart';

class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _navItems = [
    _NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      routeIndex: 0,
    ),
    _NavItem(
      label: 'Patients',
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      routeIndex: 1,
    ),
    _NavItem(
      label: 'Devices',
      icon: Icons.devices_outlined,
      activeIcon: Icons.devices,
      routeIndex: 2,
    ),
    _NavItem(
      label: 'Staff Accounts',
      icon: Icons.admin_panel_settings_outlined,
      activeIcon: Icons.admin_panel_settings,
      routeIndex: 3,
      adminOnly: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final role = authProvider.role?.toLowerCase() ?? 'receptionist';
    final isAdmin = role == 'admin';

    final visibleItems = _navItems.where((i) => !i.adminOnly || isAdmin).toList();

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
        children: [
          const SizedBox(height: 28),
          // Logo & App Name Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/saathi_logo.png',
                  height: 44,
                  width: 44,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saathi',
                      style: TextStyle(
                        fontFamily: 'Serif',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: saathiNavy,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      isAdmin ? 'Admin Portal' : 'Staff Portal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: saathiTeal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Divider(height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 16),

          // Navigation Links
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                final isSelected = currentIndex == item.routeIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => onTap(item.routeIndex),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? saathiGreen.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(
                                  color: saathiGreen.withValues(alpha: 0.3),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected ? saathiGreen : saathiInk.withValues(alpha: 0.7),
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                item.label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? saathiGreen : saathiInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // User Profile & Sign Out Footer
          const Divider(height: 1, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: saathiTeal.withValues(alpha: 0.15),
                  child: Text(
                    (role.isNotEmpty ? role[0] : 'S').toUpperCase(),
                    style: const TextStyle(
                      color: saathiNavy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: saathiNavy,
                        ),
                      ),
                      const Text(
                        'Hospital Staff',
                        style: TextStyle(
                          fontSize: 11,
                          color: saathiBodyGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: saathiBodyGrey, size: 20),
                  tooltip: 'Sign Out',
                  onPressed: () => _showSignOutDialog(context, authProvider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of the Saathi Staff Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: saathiBodyGrey)),
          ),
          TextButton(
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
            child: const Text('Sign Out', style: TextStyle(color: saathiEmergency)),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.routeIndex,
    this.adminOnly = false,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int routeIndex;
  final bool adminOnly;
}
