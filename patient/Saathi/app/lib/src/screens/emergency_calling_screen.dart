import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../theme.dart';

/// Shown immediately after the patient confirms the emergency call.
///
/// PHASE 2 SEAM — PLACEHOLDER: this screen does not place a real phone call.
/// Actually dialing needs the `url_launcher` package (or platform channel) to
/// invoke `tel:`, which was not part of this UI/UX pass's approved package
/// list. Phase 2 should replace the simulated delay below with a real
/// `tel:<hospital emergency number>` launch, ideally reading the number from
/// the patient's registered hospital record rather than hardcoding it.
class EmergencyCallingScreen extends StatefulWidget {
  const EmergencyCallingScreen({super.key});

  @override
  State<EmergencyCallingScreen> createState() => _EmergencyCallingScreenState();
}

class _EmergencyCallingScreenState extends State<EmergencyCallingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    // Deliberately not blocked with PopScope(canPop: false). This screen
    // returns itself automatically after a couple of seconds, but a patient
    // must never be stuck on a full-screen red "calling" state with no way
    // out if that timer is ever delayed — the system back gesture stays live
    // as a safety net.
    return Scaffold(
      backgroundColor: saathiEmergency,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingPhoneIcon(),
              const SizedBox(height: 28),
              Text(
                text(T.emergencyCalling),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingPhoneIcon extends StatefulWidget {
  @override
  State<_PulsingPhoneIcon> createState() => _PulsingPhoneIconState();
}

class _PulsingPhoneIconState extends State<_PulsingPhoneIcon>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: .92,
        end: 1.08,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .18),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.phone_in_talk_rounded,
          color: Colors.white,
          size: 54,
        ),
      ),
    );
  }
}
