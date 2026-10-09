import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api_client.dart';
import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../theme.dart';
import '../utils/camera_lifecycle.dart';
import '../widgets/patient_widgets.dart';
import '../widgets/saathi_logo.dart';

/// Scan the hospital's activation QR.
///
/// The chrome here is light, matching the welcome screen. Only the camera
/// viewfinder itself is dark, inset as a rounded window rather than taking
/// over the whole screen — a patient stepping from the welcome screen into
/// this one should not feel they have landed in a different app.
class QrLinkScreen extends StatefulWidget {
  const QrLinkScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<QrLinkScreen> createState() => _QrLinkScreenState();
}

class _QrLinkScreenState extends State<QrLinkScreen> {
  final scanner = MobileScannerController(autoStart: true, torchEnabled: false);
  bool isLinking = false;
  String? error;

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (isLinking) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;
    setState(() {
      isLinking = true;
      error = null;
    });
    await scanner.stop();
    stopCameraHardware();
    try {
      await widget.controller.linkWithQr(value);
      stopCameraHardware();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        isLinking = false;
      });
      await scanner.start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = AppText.of(context)(T.manualCannotConnect);
        isLinking = false;
      });
      await scanner.start();
    }
  }

  @override
  void dispose() {
    scanner.stop();
    scanner.dispose();
    stopCameraHardware();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        // Was near-black on near-black, which left the title effectively
        // invisible. The light app bar inherits the app's navy-on-cream.
        backgroundColor: colors.page,
        foregroundColor: colors.brand,
        title: Text(text(T.scanTitle)),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InstructionCard(text: text(T.scanInstruction)),
              const SizedBox(height: 14),
              Expanded(
                child: _CameraWindow(
                  scanner: scanner,
                  isLinking: isLinking,
                  onDetect: _handleCapture,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                _ScanErrorCard(message: error!),
              ],
              const SizedBox(height: 14),
              _SecondaryButton(
                label: text(T.scanUseIdInstead),
                icon: Icons.badge_outlined,
                onPressed: isLinking
                    ? null
                    : () async {
                        await scanner.stop();
                        stopCameraHardware();
                        if (!context.mounted) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ManualLinkScreen(controller: widget.controller),
                          ),
                        );
                        if (mounted &&
                            widget.controller.status == AppStatus.unlinked) {
                          await scanner.start();
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White card with a mint icon tile — the same instructional card shape used
/// on the welcome screen, so the two screens read as one flow.
class _InstructionCard extends StatelessWidget {
  const _InstructionCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primaryTint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              color: colors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.brand,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark viewfinder, inset and rounded, with corner brackets and a torch.
class _CameraWindow extends StatelessWidget {
  const _CameraWindow({
    required this.scanner,
    required this.isLinking,
    required this.onDetect,
  });

  final MobileScannerController scanner;
  final bool isLinking;
  final void Function(BarcodeCapture) onDetect;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: const Color(0xFF14201D),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: scanner,
              onDetect: onDetect,
              errorBuilder: (context, _) => _CameraUnavailable(
                title: text(T.scanCameraUnavailable),
                body: text(T.scanCameraUnavailableBody),
              ),
            ),
            // Scrim outside the frame so the brackets read as a window.
            const _ScanScrim(),
            Center(
              child: isLinking
                  ? _LinkingBadge(label: text(T.scanLinking))
                  : const _CornerBrackets(),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _TorchButton(scanner: scanner),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dims everything outside the scan frame.
///
/// Painted as a single even-odd path rather than a `BlendMode.dstOut`
/// rectangle: blend modes only punch through when the parent has its own
/// compositing layer, and when that is missing the "hole" renders as an
/// opaque square sitting over the camera. This version cannot fail that way.
class _ScanScrim extends StatelessWidget {
  const _ScanScrim();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScrimPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side = _frameSide(size);
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: side,
        height: side,
      ),
      const Radius.circular(18),
    );

    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);

    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .34));
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) => false;
}

double _frameSide(Size available) {
  final shortest = available.shortestSide;
  return (shortest * .68).clamp(150.0, 260.0);
}

/// Four green corner brackets instead of a plain white square outline.
class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = _frameSide(constraints.biggest);
        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: const [
              Positioned(top: 0, left: 0, child: _Corner(Alignment.topLeft)),
              Positioned(top: 0, right: 0, child: _Corner(Alignment.topRight)),
              Positioned(
                bottom: 0,
                left: 0,
                child: _Corner(Alignment.bottomLeft),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: _Corner(Alignment.bottomRight),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner(this.corner);
  final Alignment corner;

  @override
  Widget build(BuildContext context) {
    const thickness = 5.0;
    const length = 36.0;
    const radius = Radius.circular(12);
    const line = BorderSide(color: Color(0xFF3ECF8E), width: thickness);

    final isTop = corner.y < 0;
    final isLeft = corner.x < 0;

    return SizedBox(
      width: length,
      height: length,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? line : BorderSide.none,
            bottom: isTop ? BorderSide.none : line,
            left: isLeft ? line : BorderSide.none,
            right: isLeft ? BorderSide.none : line,
          ),
          borderRadius: BorderRadius.only(
            topLeft: isTop && isLeft ? radius : Radius.zero,
            topRight: isTop && !isLeft ? radius : Radius.zero,
            bottomLeft: !isTop && isLeft ? radius : Radius.zero,
            bottomRight: !isTop && !isLeft ? radius : Radius.zero,
          ),
        ),
      ),
    );
  }
}

/// Flashlight toggle, drawn over the dark preview where a light circular
/// button has the most contrast.
///
/// Hidden entirely — not merely disabled — when the camera reports
/// [TorchState.unavailable], which is what a device with no flash returns.
/// A control that cannot do anything is worse than no control for a patient
/// who is already unsure what to press.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.scanner});
  final MobileScannerController scanner;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: scanner,
      builder: (context, state, _) {
        final torch = state.torchState;
        if (torch == TorchState.unavailable) return const SizedBox.shrink();
        final isOn = torch == TorchState.on;
        return Semantics(
          button: true,
          label: isOn ? text(T.scanTorchOff) : text(T.scanTorchOn),
          child: Material(
            color: isOn ? colors.amber : Colors.white.withValues(alpha: .92),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () async {
                HapticFeedback.selectionClick();
                try {
                  await scanner.toggleTorch();
                } catch (_) {
                  // Some devices report a torch and then refuse to switch it
                  // on. Failing silently is correct here — the scan still
                  // works without it.
                }
              },
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  isOn
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                  color: saathiNavy,
                  size: 26,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LinkingBadge extends StatelessWidget {
  const _LinkingBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: colors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: colors.brand,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF14201D),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.no_photography_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanErrorCard extends StatelessWidget {
  const _ScanErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.emergencyTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.emergency.withValues(alpha: .5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.emergency),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.emergencyStrong,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White button with a heavy green border — real weight on a light
/// background without competing with the filled primary button.
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.primary, width: 2),
        minimumSize: const Size.fromHeight(68),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      icon: Icon(icon, size: 22),
      label: Text(label),
    );
  }
}

/// Manual fallback: type the patient ID and 6-digit activation code.
class ManualLinkScreen extends StatefulWidget {
  const ManualLinkScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<ManualLinkScreen> createState() => _ManualLinkScreenState();
}

class _ManualLinkScreenState extends State<ManualLinkScreen> {
  final formKey = GlobalKey<FormState>();
  final patientIdController = TextEditingController();
  final registrationNoController = TextEditingController();
  final deviceIdentifierController = TextEditingController(text: 'Patient Primary Device');
  final codeController = TextEditingController();
  bool loading = false;
  bool submitted = false;
  String? error;

  @override
  void dispose() {
    patientIdController.dispose();
    registrationNoController.dispose();
    deviceIdentifierController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => submitted = true);
    if (!formKey.currentState!.validate()) return;

    final pIdText = patientIdController.text.trim();
    final regNoText = registrationNoController.text.trim();

    int? patientId = int.tryParse(pIdText);
    String? registrationNo = regNoText.isNotEmpty ? regNoText : null;

    if (patientId == null && pIdText.isNotEmpty) {
      registrationNo ??= pIdText;
    }

    if (patientId == null && (registrationNo == null || registrationNo.isEmpty)) {
      setState(() => error = 'Please enter Patient ID or Registration Number.');
      return;
    }

    final deviceId = deviceIdentifierController.text.trim().isNotEmpty
        ? deviceIdentifierController.text.trim()
        : 'Patient Primary Device';
    final code = codeController.text.trim();

    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.controller.linkManually(
        patientId: patientId,
        registrationNo: registrationNo,
        deviceIdentifier: deviceId,
        activationCode: code,
      );
      stopCameraHardware();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = AppText.of(context)(T.manualCannotConnect));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final colors = context.saathiColors;
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(title: Text(text(T.manualTitle))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24,
                ),
                child: IntrinsicHeight(
                  child: Form(
                    key: formKey,
                    autovalidateMode: submitted
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: colors.primaryTint,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SaathiLogo(size: 54, showWordmark: false),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          text(T.manualHeading),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: colors.brand,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          text(T.manualSubtext),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: colors.navInactive,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _LinkField(
                          controller: patientIdController,
                          label: 'Patient ID',
                          hint: 'Enter numeric ID (e.g. 13)',
                          icon: Icons.person_pin_rounded,
                          keyboardType: TextInputType.text,
                          validator: (value) {
                            if ((value == null || value.trim().isEmpty) &&
                                registrationNoController.text.trim().isEmpty) {
                              return 'Enter Patient ID or Registration Number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _LinkField(
                          controller: registrationNoController,
                          label: 'Registration Number',
                          hint: 'Enter registration number (e.g. MA-2026-000013)',
                          icon: Icons.assignment_ind_outlined,
                          validator: (value) => null,
                        ),
                        const SizedBox(height: 14),
                        _LinkField(
                          controller: deviceIdentifierController,
                          label: 'Device Label',
                          hint: 'e.g. Patient Primary Device',
                          icon: Icons.smartphone_rounded,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Enter device label'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _LinkField(
                          controller: codeController,
                          label: 'Activation Code',
                          hint: 'Enter activation code from hospital',
                          icon: Icons.key_rounded,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Enter activation code'
                              : null,
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 14),
                          _ScanErrorCard(message: error!),
                        ],
                        const Spacer(),
                        const SizedBox(height: 20),
                        PatientPrimaryButton(
                          label: text(T.manualSubmit),
                          onPressed: loading ? null : submit,
                          busy: loading,
                        ),
                        const SizedBox(height: 12),
                        _ReassuranceRow(
                          icon: Icons.lock_outline_rounded,
                          label: text(T.manualCodeOnce),
                        ),
                        const SizedBox(height: 8),
                        // One line only: this is a form, so the keyboard
                        // covers the lower half whenever the patient is
                        // typing. The single moment someone is stuck here is
                        // not having the code, which is exactly what this
                        // answers.
                        Text(
                          text(T.manualNeedHelp),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.navInactive,
                            height: 1.3,
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
    );
  }
}



class _LinkField extends StatelessWidget {
  const _LinkField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: colors.primary),
        filled: true,
        fillColor: colors.surface,
        // Explicit focus and error borders: the shared theme's 2px green
        // focus ring, and a matching red ring plus message when validation
        // fails, so a wrong code says so instead of failing silently.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.emergency, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.emergency, width: 2),
        ),
        errorStyle: TextStyle(
          color: colors.emergency,
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
  }
}

class _ReassuranceRow extends StatelessWidget {
  const _ReassuranceRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.saathiColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.primaryTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.brand,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
