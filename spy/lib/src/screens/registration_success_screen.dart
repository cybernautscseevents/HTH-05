import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../theme.dart';
import 'patient_profile_screen.dart';

class RegistrationSuccessScreen extends StatefulWidget {
  final RegisterPatientResponse response;
  final String? assignedDoctorName;
  final VoidCallback? onExitToDashboard;

  const RegistrationSuccessScreen({
    super.key,
    required this.response,
    this.assignedDoctorName,
    this.onExitToDashboard,
  });

  @override
  State<RegistrationSuccessScreen> createState() =>
      _RegistrationSuccessScreenState();
}

class _RegistrationSuccessScreenState extends State<RegistrationSuccessScreen>
    with SingleTickerProviderStateMixin {
  RegisterPatientResponse get response => widget.response;

  late AnimationController _animController;
  late Animation<double> _contentFadeAnim;
  late Animation<Offset> _contentSlideAnim;
  late final DateTime _registeredAt;

  @override
  void initState() {
    super.initState();
    _registeredAt = DateTime.now();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _contentFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _contentSlideAnim =
        Tween<Offset>(begin: const Offset(0.0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: saathiCream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final canStretchVertically = isWide && constraints.maxHeight >= 520;
            final compact = constraints.maxHeight < 800;
            final verticalPadding = compact ? 10.0 : 20.0;
            final horizontalPadding = 24.0;

            Widget content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: compact ? 8 : 16),
                AnimatedSuccessCheckmark(
                  size: compact ? 82 : 96,
                  startDelay: const Duration(milliseconds: 120),
                ),
                SizedBox(height: compact ? 14 : 20),
                FadeTransition(
                  opacity: _contentFadeAnim,
                  child: SlideTransition(
                    position: _contentSlideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Patient Registered',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: saathiNavy,
                                fontWeight: FontWeight.w900,
                                fontSize: compact ? 22 : 26,
                              ),
                        ),
                        SizedBox(height: compact ? 2 : 4),
                        Text(
                          'Registration completed successfully for ${response.patient.fullName}.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontSize: compact ? 13 : 14),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: compact ? 12 : 20),
                if (canStretchVertically)
                  Expanded(
                    child: _buildConfirmationDetails(
                      context,
                      isWide: isWide,
                      compact: compact,
                      stretch: true,
                    ),
                  )
                else
                  _buildConfirmationDetails(
                    context,
                    isWide: isWide,
                    compact: compact,
                    stretch: false,
                  ),
              ],
            );

            Widget bodyWidget;
            if (canStretchVertically) {
              bodyWidget = Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding,
                  horizontalPadding,
                  verticalPadding,
                ),
                child: content,
              );
            } else {
              bodyWidget = SingleChildScrollView(
                physics: constraints.maxHeight >= 480
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding,
                  horizontalPadding,
                  verticalPadding,
                ),
                child: content,
              );
            }

            return Stack(
              children: [
                bodyWidget,
                Positioned(
                  top: 12,
                  right: 18,
                  child: OutlinedButton.icon(
                    onPressed: _exitToDashboard,
                    icon: const Icon(
                      Icons.exit_to_app_rounded,
                      size: 19,
                      color: saathiNavy,
                    ),
                    label: const Text('Exit to Dashboard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: saathiNavy,
                      side: const BorderSide(color: saathiLine, width: 1.5),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(child: _CelebrationConfettiOverlay()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildConfirmationDetails(
    BuildContext context, {
    required bool isWide,
    bool compact = false,
    bool stretch = false,
  }) {
    final age = _ageForDateOfBirth(response.patient.dateOfBirth);
    final details = [
      _buildDetailRow(
        context,
        'Name',
        response.patient.fullName,
        compact: compact,
      ),
      if (response.patient.dateOfBirth != null)
        _buildDetailRow(
          context,
          'Date of Birth',
          response.patient.dateOfBirth!,
          compact: compact,
        ),
      if (age != null) _buildDetailRow(context, 'Age', age, compact: compact),
      if (response.patient.diseaseCondition != null)
        _buildDetailRow(
          context,
          'Condition',
          response.patient.diseaseCondition!,
          compact: compact,
        ),
      if (response.patient.emergencyContact != null)
        _buildDetailRow(
          context,
          'Phone Number',
          response.patient.emergencyContact!,
          compact: compact,
        ),
      _buildDetailRow(
        context,
        'Language',
        response.patient.preferredLanguage,
        compact: compact,
      ),
      _buildDetailRow(
        context,
        'Assigned Doctor',
        widget.assignedDoctorName ?? 'Not assigned',
        compact: compact,
      ),
    ];

    final registrationContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('REGISTRATION NUMBER', style: _panelLabelStyle),
        SizedBox(height: compact ? 6 : 8),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                response.registrationNo ?? response.patientUid ?? '—',
                style: TextStyle(
                  fontSize: compact ? 22 : 26,
                  fontWeight: FontWeight.w900,
                  color: saathiTeal,
                  fontFamily: 'monospace',
                  letterSpacing: 1.2,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined, color: saathiTeal),
              iconSize: compact ? 22 : 25,
              tooltip: 'Copy registration number',
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text: response.registrationNo ?? response.patientUid ?? '',
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Registration number copied to clipboard'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
        Divider(color: saathiLine, height: compact ? 12 : 22),
        _buildInfoValue(
          'Patient ID',
          response.patientId?.toString() ?? '—',
          compact: compact,
        ),
        SizedBox(height: compact ? 8 : 12),
        _buildInfoValue(
          'Registration time',
          _formatTime(_registeredAt),
          compact: compact,
        ),
        SizedBox(height: compact ? 8 : 12),
        _buildInfoValue(
          'Registration date',
          _formatDate(_registeredAt),
          compact: compact,
        ),
      ],
    );

    final patientContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: details,
    );

    final registrationAction = FilledButton.icon(
      onPressed: () => Navigator.pop(context),
      icon: Icon(Icons.person_add_alt_1_outlined, size: compact ? 16 : 18),
      label: const Text('Register Another'),
    );

    final patientAction = FilledButton.icon(
      onPressed: _viewPatient,
      icon: Icon(Icons.person_outline, size: compact ? 16 : 18),
      label: const Text('View Patient'),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildPanelColumn(
              title: 'REGISTRATION DETAILS',
              details: registrationContent,
              action: registrationAction,
              stretch: stretch,
              compact: compact,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildPanelColumn(
              title: 'PATIENT DETAILS',
              details: patientContent,
              action: patientAction,
              stretch: stretch,
              compact: compact,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPanelColumn(
          title: 'REGISTRATION DETAILS',
          details: registrationContent,
          action: registrationAction,
          stretch: false,
          compact: compact,
        ),
        const SizedBox(height: 16),
        _buildPanelColumn(
          title: 'PATIENT DETAILS',
          details: patientContent,
          action: patientAction,
          stretch: false,
          compact: compact,
        ),
      ],
    );
  }

  static const _panelLabelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: saathiBodyGrey,
    letterSpacing: 1.1,
  );

  Widget _buildHeaderBox(String title, {bool compact = false}) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 16 : 22,
      vertical: compact ? 9 : 13,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: saathiLine, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Text(
      title,
      style: TextStyle(
        fontSize: compact ? 16 : 20,
        fontWeight: FontWeight.w900,
        color: saathiNavy,
        letterSpacing: 1.1,
      ),
    ),
  );

  Widget _buildDetailsBox(Widget child, {bool compact = false}) => Card(
    color: Colors.white,
    elevation: 1.5,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: saathiLine),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 26,
        vertical: compact ? 12 : 20,
      ),
      child: child,
    ),
  );

  Widget _buildPanelColumn({
    required String title,
    required Widget details,
    required Widget action,
    required bool stretch,
    bool compact = false,
  }) {
    final headerBox = _buildHeaderBox(title, compact: compact);
    final detailsBox = _buildDetailsBox(details, compact: compact);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        headerBox,
        SizedBox(height: compact ? 8 : 10),
        if (stretch) Expanded(child: detailsBox) else detailsBox,
        SizedBox(height: compact ? 10 : 14),
        SizedBox(
          height: compact ? 40 : 48,
          child: Theme(
            data: Theme.of(context).copyWith(
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(backgroundColor: saathiGreen),
              ),
            ),
            child: action,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoValue(String label, String value, {bool compact = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: _panelLabelStyle),
          SizedBox(height: compact ? 3 : 5),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: saathiNavy,
            ),
          ),
        ],
      );

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatDate(DateTime dateTime) {
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
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }

  String? _ageForDateOfBirth(String? dateOfBirth) {
    final date = dateOfBirth == null ? null : DateTime.tryParse(dateOfBirth);
    if (date == null) return null;

    final today = DateTime.now();
    var age = today.year - date.year;
    if (today.month < date.month ||
        (today.month == date.month && today.day < date.day)) {
      age--;
    }
    return age < 0 ? null : '$age years';
  }

  void _viewPatient() {
    final patientResult = PatientSearchResult(
      patientId: response.patientId ?? 0,
      registrationNo: response.registrationNo ?? response.patientUid ?? '—',
      name: response.patient.fullName,
      dateOfBirth: response.patient.dateOfBirth,
      diseaseCondition: response.patient.diseaseCondition,
      preferredLanguage: response.patient.preferredLanguage,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PatientProfileScreen(patient: patientResult),
      ),
    );
  }

  void _exitToDashboard() {
    if (widget.onExitToDashboard != null) {
      Navigator.pop(context);
      widget.onExitToDashboard!();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool compact = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4.5 : 6.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: compact ? 140 : 160,
            child: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: saathiBodyGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w700,
                color: saathiInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen Paytm-style celebration confetti shower.
enum _ConfettiShape { rectangle, circle, star }

class _ConfettiParticle {
  final double xOffset;
  final double vx;
  final double vy;
  final double gravity;
  final double drag;
  final double width;
  final double height;
  final Color color;
  final _ConfettiShape shape;
  final double rotSpeedX;
  final double rotSpeedY;
  final double rotSpeedZ;
  final double initRotZ;
  final double swayFreq;
  final double swayAmp;
  final double swayPhase;
  final double delay;

  const _ConfettiParticle({
    required this.xOffset,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.drag,
    required this.width,
    required this.height,
    required this.color,
    required this.shape,
    required this.rotSpeedX,
    required this.rotSpeedY,
    required this.rotSpeedZ,
    required this.initRotZ,
    required this.swayFreq,
    required this.swayAmp,
    required this.swayPhase,
    required this.delay,
  });
}

class _CelebrationConfettiOverlay extends StatefulWidget {
  const _CelebrationConfettiOverlay();

  @override
  State<_CelebrationConfettiOverlay> createState() =>
      _CelebrationConfettiOverlayState();
}

class _CelebrationConfettiOverlayState
    extends State<_CelebrationConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    _particles = _generateConfettiParticles(count: 85);
    _startTimer = Timer(const Duration(milliseconds: 1450), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isAnimating && !_controller.isCompleted) {
          return const SizedBox.shrink();
        }
        return CustomPaint(
          painter: _FullConfettiPainter(
            progress: _controller.value,
            particles: _particles,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

List<_ConfettiParticle> _generateConfettiParticles({int count = 85}) {
  final random = math.Random(1337);
  const colors = [
    Color(0xFF00BAF2), // Paytm Blue
    Color(0xFF00B074), // Saathi Green
    Color(0xFFFFB800), // Gold Amber
    Color(0xFFFF477E), // Radiant Pink
    Color(0xFF8B5CF6), // Purple
    Color(0xFF00D2B4), // Mint Teal
    Color(0xFFFF7A00), // Tangerine
  ];

  final particles = <_ConfettiParticle>[];
  for (int i = 0; i < count; i++) {
    final angleDeg = 190.0 + random.nextDouble() * 160.0;
    final angleRad = angleDeg * math.pi / 180.0;
    final speed = 360.0 + random.nextDouble() * 480.0;

    final vx = math.cos(angleRad) * speed;
    final vy = math.sin(angleRad) * speed * 0.95;

    final shapeVal = random.nextDouble();
    final shape = shapeVal < 0.60
        ? _ConfettiShape.rectangle
        : (shapeVal < 0.85 ? _ConfettiShape.circle : _ConfettiShape.star);

    final w = shape == _ConfettiShape.circle
        ? (5.0 + random.nextDouble() * 5.0)
        : (shape == _ConfettiShape.star
              ? (8.0 + random.nextDouble() * 6.0)
              : (6.0 + random.nextDouble() * 6.0));
    final h = shape == _ConfettiShape.rectangle
        ? (10.0 + random.nextDouble() * 14.0)
        : w;

    particles.add(
      _ConfettiParticle(
        xOffset: (random.nextDouble() - 0.5) * 60.0,
        vx: vx,
        vy: vy,
        gravity: 500.0 + random.nextDouble() * 220.0,
        drag: 0.965,
        width: w,
        height: h,
        color: colors[random.nextInt(colors.length)],
        shape: shape,
        rotSpeedX: 3.0 + random.nextDouble() * 8.0,
        rotSpeedY: 2.0 + random.nextDouble() * 7.0,
        rotSpeedZ: (random.nextDouble() - 0.5) * 6.0,
        initRotZ: random.nextDouble() * math.pi * 2,
        swayFreq: 2.5 + random.nextDouble() * 4.0,
        swayAmp: 18.0 + random.nextDouble() * 26.0,
        swayPhase: random.nextDouble() * math.pi * 2,
        delay: (i < 45 ? 0.0 : random.nextDouble() * 0.35),
      ),
    );
  }
  return particles;
}

class _FullConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  const _FullConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final totalTime = progress * 3.8;
    final origin = Offset(size.width * 0.5, size.height * 0.11);
    final fade = progress < 0.70
        ? 1.0
        : (1.0 - ((progress - 0.70) / 0.30)).clamp(0.0, 1.0);
    final paint = Paint();

    for (final p in particles) {
      if (totalTime < p.delay) continue;
      final t = totalTime - p.delay;
      final dragFactor = math.pow(p.drag, t * 60).toDouble();

      final currentX =
          origin.dx +
          p.xOffset +
          (p.vx * (1 - dragFactor) / 3.0) +
          math.sin(t * p.swayFreq + p.swayPhase) *
              p.swayAmp *
              (t / 1.5).clamp(0.0, 1.0);

      final currentY =
          origin.dy +
          (p.vy * (1 - dragFactor) / 3.0) +
          (0.5 * p.gravity * t * t);

      if (currentY > size.height + 40) continue;

      final rotX = t * p.rotSpeedX;
      final rotY = t * p.rotSpeedY;
      final rotZ = p.initRotZ + (t * p.rotSpeedZ);

      final scaleX = math.cos(rotX).abs();
      final scaleY = math.cos(rotY).abs();

      paint.color = p.color.withValues(alpha: fade * (0.85 + (scaleX * 0.15)));

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(rotZ);
      canvas.scale(scaleX, scaleY);

      if (p.shape == _ConfettiShape.circle) {
        canvas.drawCircle(Offset.zero, p.width * 0.5, paint);
      } else if (p.shape == _ConfettiShape.rectangle) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.width,
            height: p.height,
          ),
          paint,
        );
      } else {
        final r = p.width * 0.7;
        final path = Path();
        path.moveTo(0, -r);
        path.lineTo(r * 0.35, -r * 0.35);
        path.lineTo(r, 0);
        path.lineTo(r * 0.35, r * 0.35);
        path.lineTo(0, r);
        path.lineTo(-r * 0.35, r * 0.35);
        path.lineTo(-r, 0);
        path.lineTo(-r * 0.35, -r * 0.35);
        path.close();
        canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FullConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Paytm / Payment-app style live right-mark animation with confetti theme:
/// 1. Starts from a small center dot (no checkmark drawn).
/// 2. Dot elastically expands into a vibrant circular green badge with ripple shockwaves.
/// 3. White right mark (checkmark) draws live stroke-by-stroke with a glowing pen-tip leading it.
/// 4. Elastic bounce settle on completion and gentle ambient glow breath.
class AnimatedSuccessCheckmark extends StatefulWidget {
  final double size;
  final Duration startDelay;

  const AnimatedSuccessCheckmark({
    super.key,
    this.size = 84.0,
    this.startDelay = Duration.zero,
  });

  @override
  State<AnimatedSuccessCheckmark> createState() =>
      _AnimatedSuccessCheckmarkState();
}

class _AnimatedSuccessCheckmarkState extends State<AnimatedSuccessCheckmark>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _ripple1Animation;
  late Animation<double> _ripple2Animation;
  late Animation<double> _rippleOpacity;
  late Animation<double> _punchAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // 1. Initial dot -> expanding bounce into full circle: 0.0 to 0.42
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.16, end: 0.16),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.16,
          end: 1.14,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 27,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.14,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 12,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 46),
    ]).animate(_controller);

    // 2. Ripple rings bursting outward as circle expands
    _ripple1Animation = Tween<double>(begin: 0.8, end: 1.55).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.22, 0.70, curve: Curves.easeOutCubic),
      ),
    );
    _ripple2Animation = Tween<double>(begin: 0.8, end: 1.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _rippleOpacity = Tween<double>(begin: 0.65, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.22, 0.85, curve: Curves.easeOut),
      ),
    );

    // 3. Live checkmark stroke drawing
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.76, curve: Curves.easeInOutCubic),
      ),
    );

    // 4. Subtle punch bounce when stroke completes: 0.88 to 1.0
    _punchAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 88),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.07,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 5,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.07,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 7,
      ),
    ]).animate(_controller);

    Future.delayed(widget.startDelay, () {
      if (!mounted) return;
      _controller.forward().whenComplete(() {
        if (mounted) {
          // Play a couple of gentle pulses then stop, keeping mark clean & idle
          // without blocking flutter_test's pumpAndSettle.
          _pulseController.forward(from: 0.0);
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _pulseController]),
        builder: (context, child) {
          final pulse = _controller.isCompleted
              ? 1.0 + (_pulseController.value * 0.05)
              : 1.0;
          final currentScale =
              _scaleAnimation.value * _punchAnimation.value * pulse;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Outer Ripple Shockwave
                if (!_controller.isCompleted && _ripple2Animation.value > 0.8)
                  Transform.scale(
                    scale: _ripple2Animation.value,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: saathiGreen.withValues(
                          alpha: _rippleOpacity.value * 0.4,
                        ),
                      ),
                    ),
                  ),

                // Inner Ripple Shockwave
                if (!_controller.isCompleted && _ripple1Animation.value > 0.8)
                  Transform.scale(
                    scale: _ripple1Animation.value,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: saathiGreen.withValues(
                          alpha: _rippleOpacity.value * 0.75,
                        ),
                      ),
                    ),
                  ),

                // Main Circle / Dot Badge (Clean, without green shadow)
                Transform.scale(
                  scale: currentScale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: saathiGreen,
                    ),
                    child: CustomPaint(
                      painter: _LiveCheckmarkPainter(
                        progress: _checkAnimation.value,
                        color: Colors.white,
                        strokeWidth: widget.size * 0.092,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LiveCheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _LiveCheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return;

    final w = size.width;
    final h = size.height;

    // Classic Paytm / UPI checkmark geometry
    final p1 = Offset(w * 0.28, h * 0.53);
    final p2 = Offset(w * 0.44, h * 0.69);
    final p3 = Offset(w * 0.74, h * 0.35);

    final len1 = (p2 - p1).distance;
    final len2 = (p3 - p2).distance;
    final totalLen = len1 + len2;
    final frac1 = len1 / totalLen;

    final path = Path();
    path.moveTo(p1.dx, p1.dy);

    late Offset currentTip;

    if (progress <= frac1) {
      final t = (progress / frac1).clamp(0.0, 1.0);
      currentTip = Offset.lerp(p1, p2, t)!;
      path.lineTo(currentTip.dx, currentTip.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = ((progress - frac1) / (1.0 - frac1)).clamp(0.0, 1.0);
      currentTip = Offset.lerp(p2, p3, t)!;
      path.lineTo(currentTip.dx, currentTip.dy);
    }

    // Outer soft glow for stroke
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.85);
    canvas.drawPath(path, glowPaint);

    // Main sharp crisp stroke
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Live glowing pen-tip leading the drawing
    if (progress > 0.01 && progress < 0.99) {
      final tipGlow = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.75);
      canvas.drawCircle(currentTip, strokeWidth * 0.85, tipGlow);

      final tipCore = Paint()..color = Colors.white;
      canvas.drawCircle(currentTip, strokeWidth * 0.55, tipCore);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveCheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
