import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../services/reminder_service.dart';
import '../theme.dart';

/// The floating "read this screen to me" control, behaving like iOS
/// AssistiveTouch: the patient can drag it anywhere and it settles against the
/// nearest side.
///
/// It floats rather than sitting in the header because it is the one control
/// on the dashboard a patient may need while looking at any part of the
/// screen, and because a fixed control in a corner is unreachable one-handed
/// on a large phone. Letting them park it where their thumb actually rests is
/// the point — so the position is remembered between launches
/// ([AppController.setListenBallPosition]) rather than resetting to a default
/// they have to correct every time.
///
/// Must be a direct child of a [Stack]: it builds a [Positioned], so it paints
/// above the dashboard without taking part in its layout.
class DraggableListenBall extends StatefulWidget {
  const DraggableListenBall({
    super.key,
    required this.controller,
    required this.bounds,
    required this.onListen,
  });

  final AppController controller;

  /// The area the ball may move in — the Stack's own size.
  final Size bounds;

  /// Invoked on a tap, never on a drag.
  final VoidCallback onListen;

  /// Diameter of the ball. Comfortably past the 48dp minimum touch target,
  /// since the patients who need it most have the least steady hands.
  static const double diameter = 64;

  /// Clearance kept between the ball and the edges of [bounds].
  static const double margin = 12;

  /// Clearance kept below the top of [bounds], so the ball can never come to
  /// rest over the header. See the note on `_DraggableListenBallState`'s
  /// private copy of this value for why it is a fixed constant rather than
  /// the header's exact measured height.
  static const double headerClearance = 92;

  @override
  State<DraggableListenBall> createState() => _DraggableListenBallState();
}

class _DraggableListenBallState extends State<DraggableListenBall> {
  /// Top-left of the ball, in [DraggableListenBall.bounds] coordinates.
  Offset? _position;
  bool _dragging = false;

  EdgeInsets get _safeInsets => MediaQuery.paddingOf(context);

  /// The rectangle the ball's top-left corner may occupy. Excludes the header
  /// at the top — [DraggableListenBall.headerClearance] — and the system
  /// gesture bar at the bottom, either of which would otherwise let the ball
  /// come to rest over a control the patient needs, or swallow taps on a ball
  /// parked in the bottom corner.
  ///
  /// The header clearance is a fixed constant rather than the header's exact
  /// measured height: the header grows at large text scales (it wraps to two
  /// lines past 1.3x), and erring toward "a little too much clearance" costs
  /// nothing, while erring the other way lets the ball sit on top of a
  /// control it should stay clear of.
  Rect _travel(Size bounds) {
    const d = DraggableListenBall.diameter;
    const m = DraggableListenBall.margin;
    final left = m;
    final top = DraggableListenBall.headerClearance;
    final right = (bounds.width - d - m).clamp(left, double.infinity);
    final bottom = (bounds.height - d - m - _safeInsets.bottom).clamp(
      top,
      double.infinity,
    );
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Offset _resolve(Size bounds) {
    final travel = _travel(bounds);
    final saved = _position;
    if (saved != null) {
      return Offset(
        saved.dx.clamp(travel.left, travel.right),
        saved.dy.clamp(travel.top, travel.bottom),
      );
    }

    final x = widget.controller.listenBallX;
    final y = widget.controller.listenBallY;
    if (x != null && y != null) {
      return Offset(
        travel.left + (travel.right - travel.left) * x.clamp(0.0, 1.0),
        travel.top + (travel.bottom - travel.top) * y.clamp(0.0, 1.0),
      );
    }

    // First launch: the design's default corner — low and to the right, clear
    // of the emergency card above it.
    return Offset(travel.right, travel.bottom);
  }

  void _onPanStart(DragStartDetails _) {
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details, Size bounds) {
    final travel = _travel(bounds);
    final next = (_position ?? _resolve(bounds)) + details.delta;
    setState(() {
      _position = Offset(
        next.dx.clamp(travel.left, travel.right),
        next.dy.clamp(travel.top, travel.bottom),
      );
    });
  }

  void _onPanEnd(Size bounds) {
    final travel = _travel(bounds);
    final current = _position ?? _resolve(bounds);

    // Snap to whichever side the ball is nearer, AssistiveTouch style. The
    // vertical position is kept as dropped — only the horizontal side is
    // decided for them.
    final centreX = current.dx + DraggableListenBall.diameter / 2;
    final snappedX = centreX < bounds.width / 2 ? travel.left : travel.right;
    final settled = Offset(snappedX, current.dy);

    setState(() {
      _dragging = false;
      _position = settled;
    });

    final spanX = travel.right - travel.left;
    final spanY = travel.bottom - travel.top;
    widget.controller.setListenBallPosition(
      spanX <= 0 ? 0 : (settled.dx - travel.left) / spanX,
      spanY <= 0 ? 0 : (settled.dy - travel.top) / spanY,
    );

    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final bounds = widget.bounds;
    final position = _resolve(bounds);
    final text = AppText.of(context);
    final colors = context.saathiColors;

    return AnimatedPositioned(
      left: position.dx,
      top: position.dy,
      // Follows the finger exactly while dragging; eases into place on
      // release.
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: ValueListenableBuilder<bool>(
        valueListenable: ReminderService.instance.isSpeaking,
        builder: (context, speaking, _) {
          // Same rule as every other Listen control in the app: while the
          // engine is talking, this becomes the way to stop it.
          final label = speaking
              ? text(T.dashboardStopSpeaking)
              : text(T.dashboardListenScreen);
          final fill = speaking ? colors.emergency : colors.primaryStrong;

          return Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Tap and pan are mutually exclusive here: a pointer that
              // travels past the drag slop is claimed by the pan recogniser
              // and never reaches onTap, so dragging cannot start speech.
              onTap: () {
                HapticFeedback.selectionClick();
                if (speaking) {
                  ReminderService.instance.stopSpeaking();
                } else {
                  widget.onListen();
                }
              },
              onPanStart: _onPanStart,
              onPanUpdate: (d) => _onPanUpdate(d, bounds),
              onPanEnd: (_) => _onPanEnd(bounds),
              child: _Ball(fill: fill, speaking: speaking),
            ),
          );
        },
      ),
    );
  }
}

class _Ball extends StatelessWidget {
  const _Ball({required this.fill, required this.speaking});

  final Color fill;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    const d = DraggableListenBall.diameter;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        boxShadow: [
          // Two layers: a wide soft glow that lifts it off whatever card it
          // happens to be floating over, and a tight one that keeps its edge
          // readable against a pale background.
          BoxShadow(
            color: fill.withValues(alpha: .34),
            blurRadius: 22,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
        size: d * .48,
        color: Colors.white,
      ),
    );
  }
}
