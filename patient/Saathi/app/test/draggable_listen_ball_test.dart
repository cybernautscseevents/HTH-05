import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi_app/src/app_controller.dart';
import 'package:saathi_app/src/services/reminder_service.dart';
import 'package:saathi_app/src/widgets/draggable_listen_ball.dart';

/// The floating Listen ball's AssistiveTouch behaviour: draggable anywhere
/// within bounds, snaps to the nearer side on release, a tap (not a drag)
/// triggers Listen, and the settled position is written back to the
/// controller so it survives the next launch.
void main() {
  tearDown(() {
    ReminderService.instance.isSpeaking.value = false;
  });

  Widget harness(AppController controller, VoidCallback onListen) {
    return MaterialApp(
      home: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              DraggableListenBall(
                controller: controller,
                bounds: constraints.biggest,
                onListen: onListen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppController freshController() =>
      AppController(storage: const FlutterSecureStorage());

  testWidgets('starts in the bottom-right corner by default', (tester) async {
    tester.view.physicalSize = const Size(400, 800) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(freshController(), () {}));
    await tester.pumpAndSettle();

    final ball = tester.getRect(find.byType(DraggableListenBall));
    // Right edge, low on the screen — never dead centre and never top.
    expect(ball.right, closeTo(400 - DraggableListenBall.margin, 1));
    expect(ball.top, greaterThan(400));
  });

  testWidgets('a plain tap triggers Listen and does not move the ball', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    var listened = 0;
    await tester.pumpWidget(harness(freshController(), () => listened++));
    await tester.pumpAndSettle();

    final before = tester.getRect(find.byType(DraggableListenBall));
    await tester.tap(find.byType(DraggableListenBall));
    await tester.pumpAndSettle();
    final after = tester.getRect(find.byType(DraggableListenBall));

    expect(listened, 1);
    expect(after, before);
  });

  testWidgets('while speaking, a tap stops the engine instead of restarting '
      'it', (tester) async {
    tester.view.physicalSize = const Size(400, 800) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    var listened = 0;
    await tester.pumpWidget(harness(freshController(), () => listened++));
    await tester.pumpAndSettle();

    ReminderService.instance.isSpeaking.value = true;
    await tester.pump();

    await tester.tap(find.byType(DraggableListenBall));
    await tester.pump();

    expect(listened, 0);
    expect(ReminderService.instance.isSpeaking.value, isFalse);
  });

  testWidgets('dragging left of centre and releasing snaps to the left edge, '
      'and persists that position', (tester) async {
    tester.view.physicalSize = const Size(400, 800) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final controller = freshController();
    await tester.pumpWidget(harness(controller, () {}));
    await tester.pumpAndSettle();

    // Starts on the right; drag it well past the midline and up the screen.
    await tester.drag(
      find.byType(DraggableListenBall),
      const Offset(-350, -300),
    );
    await tester.pumpAndSettle();

    final settled = tester.getRect(find.byType(DraggableListenBall));
    expect(settled.left, closeTo(DraggableListenBall.margin, 1));

    // The controller now remembers a position close to the left edge.
    expect(controller.listenBallX, isNotNull);
    expect(controller.listenBallX!, lessThan(0.1));
  });

  testWidgets('dragging does not trigger Listen, only releasing does not '
      'either', (tester) async {
    tester.view.physicalSize = const Size(400, 800) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    var listened = 0;
    await tester.pumpWidget(harness(freshController(), () => listened++));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(DraggableListenBall),
      const Offset(-200, -100),
    );
    await tester.pumpAndSettle();

    expect(listened, 0);
  });

  testWidgets('a saved position is restored on the next launch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final controller = freshController();
    // Simulate a previous session having parked it top-left.
    controller.listenBallX = 0.0;
    controller.listenBallY = 0.0;

    await tester.pumpWidget(harness(controller, () {}));
    await tester.pumpAndSettle();

    final ball = tester.getRect(find.byType(DraggableListenBall));
    expect(ball.left, closeTo(DraggableListenBall.margin, 1));
    // Not `margin` — the header clearance keeps even a saved "0" from
    // landing on top of the logo and menu button.
    expect(ball.top, closeTo(DraggableListenBall.headerClearance, 1));
  });

  testWidgets('the ball stays within bounds while dragged past the edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(freshController(), () {}));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DraggableListenBall)),
    );
    // Drag far past every edge in one go.
    await gesture.moveBy(const Offset(-2000, -2000));
    await tester.pump();

    final mid = tester.getRect(find.byType(DraggableListenBall));
    expect(mid.left, greaterThanOrEqualTo(0));
    expect(mid.top, greaterThanOrEqualTo(0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging toward the top stops short of the header, never '
      'covering it', (tester) async {
    tester.view.physicalSize = const Size(400, 800) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(freshController(), () {}));
    await tester.pumpAndSettle();

    // Drag it straight up, as far as the gesture will go.
    await tester.drag(find.byType(DraggableListenBall), const Offset(0, -700));
    await tester.pumpAndSettle();

    final ball = tester.getRect(find.byType(DraggableListenBall));
    expect(ball.top, closeTo(DraggableListenBall.headerClearance, 1));
  });
}
