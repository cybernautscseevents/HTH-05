import 'package:flutter/material.dart';
import '../theme.dart';
import 'login_screen.dart';

import '../widgets/watermark_background.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: saathiCream,
      body: WatermarkBackground(
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/saathi_logo.png',
                      height: 140,
                      width: 140,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Saathi',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: saathiNavy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'STAFF PORTAL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: saathiNavy,
                    letterSpacing: 4.0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Choose your role to log in to the portal',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: saathiBodyGrey,
                      ),
                ),
              ),
              const SizedBox(height: 48),
              LayoutBuilder(
                builder: (context, constraints) {
                  final staffCard = _RoleCard(
                    title: 'Hospital Staff',
                    subtitle: 'Receptionist, Administrator, or Support Staff',
                    icon: Icons.badge_outlined,
                    backgroundColor: saathiNavy,
                    foregroundColor: saathiCream,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(role: 'Hospital Staff'),
                      ),
                    ),
                  );
                  final doctorCard = _RoleCard(
                    title: 'Doctor',
                    subtitle: 'Physicians, Specialists, and Clinical Officers',
                    icon: Icons.local_hospital_outlined,
                    backgroundColor: saathiGreen,
                    foregroundColor: saathiCream,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(role: 'Doctor'),
                      ),
                    ),
                  );
                  final isWide = constraints.maxWidth >= 700;
                  if (isWide) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(child: SizedBox(height: 340, child: staffCard)),
                        const SizedBox(width: 24),
                        Expanded(child: SizedBox(height: 340, child: doctorCard)),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      staffCard,
                      const SizedBox(height: 24),
                      doctorCard,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Dynamic scale and shadow based on interactive state
    final double scale = _isPressed ? 0.98 : (_isHovered ? 1.02 : 1.0);
    final double elevation = _isPressed ? 2.0 : (_isHovered ? 8.0 : 4.0);

    // Diagonal gradients using predefined colors
    final List<Color> gradientColors = widget.backgroundColor == saathiNavy
        ? [saathiNavy, saathiBlue]
        : [saathiGreen, saathiTeal];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Card(
            elevation: elevation,
            shadowColor: widget.backgroundColor.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), // Consistent 16px corner radius
              side: BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Increased icon scale for illustration presence
                    Icon(
                      widget.icon,
                      size: 68,
                      color: widget.foregroundColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: widget.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: widget.foregroundColor.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: widget.onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.foregroundColor,
                        foregroundColor: widget.backgroundColor,
                        minimumSize: const Size(160, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16), // Consistent 16px corner radius
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
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
}
