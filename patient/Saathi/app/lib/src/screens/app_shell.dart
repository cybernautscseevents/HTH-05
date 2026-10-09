import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../theme.dart';
import '../utils/camera_lifecycle.dart';
import '../widgets/language_switch.dart';
import '../widgets/patient_widgets.dart';
import '../widgets/saathi_logo.dart';
import 'linking_screens.dart';
import 'patient_dashboard_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.status == AppStatus.patientLinked) {
          stopCameraHardware();
        }
        return switch (controller.status) {
          AppStatus.loading => const _LoadingScreen(),
          AppStatus.offline => _OfflineScreen(controller: controller),
          AppStatus.patientLinked => PatientDashboardScreen(
            controller: controller,
          ),
          AppStatus.unlinked => PatientWelcomeScreen(
            controller: controller,
            onLogin: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QrLinkScreen(controller: controller),
              ),
            ),
          ),
        };
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatientStateView.loading(title: AppText.of(context)(T.pleaseWait)),
    );
  }
}

/// Shown when the device is still linked to the hospital but the app could
/// not reach the server — a dropped signal, the hospital's network being
/// down, and so on. Distinct from the unlinked/welcome screen: nothing here
/// suggests the patient's registration was lost.
class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Scaffold(
      body: SafeArea(
        child: PatientStateView(
          icon: Icons.cloud_off_rounded,
          tone: context.saathiColors.info,
          title: text(T.cannotReachHospital),
          body: text(T.cannotReachHospitalBody),
          actionLabel: text(T.tryAgain),
          onAction: controller.retry,
        ),
      ),
    );
  }
}

/// The one-time hospital login screen — the first thing a patient ever sees.
///
/// Nothing here is a self-service login. Hospital staff link the device once,
/// and after that the patient never sees a sign-in or sign-out control again.
/// The copy and the call to action are both written to make that division of
/// labour obvious.
class PatientWelcomeScreen extends StatelessWidget {
  const PatientWelcomeScreen({
    super.key,
    required this.controller,
    required this.onLogin,
  });
  final AppController controller;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    return Scaffold(
      // Deliberately spacious. Two equal flexible gaps — one above the hero
      // card, one between the body copy and the button — split whatever
      // height the screen has left over, so the whitespace scales with the
      // device instead of collapsing to one side. On a screen too short for
      // the content both gaps go to zero and the page scrolls; nothing is
      // ever shrunk below its defined size.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // A wide desktop viewport would otherwise make the 640:250 hero
            // nearly 730px tall. Cap it so the complete activation flow stays
            // visible without scrolling.
            final heroHeight = constraints.maxWidth >= 900 ? 420.0 : null;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 26,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Language switch aligned to top-right
                      Align(
                        alignment: Alignment.centerRight,
                        child: LanguageSwitchButton(controller: controller),
                      ),
                      const SizedBox(height: 8),
                      // Portal header — logo + name + subtitle, centred like staff portal
                      _WelcomeHeader(),
                      const SizedBox(height: 24),
                      const Spacer(),
                      _HeroIllustrationCard(height: heroHeight),
                      const SizedBox(height: 18),
                      Text(
                        text(T.welcomeHeading),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: colors.brand,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        text(T.welcomeBody),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.navInactive,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Spacer(),
                      PatientPrimaryButton(
                        label: text(T.askStaffToActivate),
                        onPressed: onLogin,
                      ),
                      const SizedBox(height: 12),
                      const _NextStepLine(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Centred portal header.
///
/// The supplied full logo is a JPEG lockup with a white background and its
/// own wordmark.  It looked like a separate white tile on coloured themes and
/// repeated "Saathi" below it.  Use the transparent emblem instead, with one
/// accessible live-text wordmark beneath it.
class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SaathiLogo(size: 152, showWordmark: false),
          const SizedBox(height: 12),
          Text(
            'Saathi',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: colors.brand,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'PATIENT PORTAL',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: colors.brand,
              letterSpacing: 4.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your health, in your hands',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.navInactive,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero illustration: hospital → secure link → phone, with the activation QR.
class _HeroIllustrationCard extends StatelessWidget {
  const _HeroIllustrationCard({this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.surfaceRaised, colors.primaryTint],
          ),
        ),
        child: height == null
            ? AspectRatio(aspectRatio: 640 / 250, child: _buildArtwork(context))
            : SizedBox(height: height, child: _buildArtwork(context)),
      ),
    );
  }

  Widget _buildArtwork(BuildContext context) {
    return SvgPicture.asset(
      'assets/illustrations/hospital_link.svg',
      fit: BoxFit.contain,
    );
  }
}

class _NextStepLine extends StatelessWidget {
  const _NextStepLine();

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.gpp_good_rounded, color: colors.brand, size: 15),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text(T.nextStepScanner),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.navInactive,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
