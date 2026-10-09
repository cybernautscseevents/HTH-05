import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The hero illustration is an SVG asset, so a malformed path or an
/// unsupported feature would only surface at runtime as a blank card. This
/// parses the real asset and fails loudly if it cannot be rendered.
void main() {
  testWidgets('hospital_link.svg parses and renders', (tester) async {
    late final Widget svg;
    svg = SvgPicture.asset('assets/illustrations/hospital_link.svg');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: svg)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
