// Simulates what an Android launcher actually draws for the adaptive icon,
// so the result can be checked before it ships to a device.
//
// It reproduces the real pipeline: the generated foreground drawable, the
// 16% inset that flutter_launcher_icons writes into
// mipmap-anydpi-v26/ic_launcher.xml, the background colour from colors.xml,
// and a circular mask (the harshest of the shapes launchers apply). Output is
// rendered large and at 48px, because "legible as a tiny home-screen icon" is
// the thing that actually matters.
//
// Run from the app/ directory:
//   dart run tool/preview_adaptive_icon.dart
//
// Writes to build/ — preview only, never shipped.

import 'dart:io';

import 'package:image/image.dart';

/// Matches `android:inset="16%"` in mipmap-anydpi-v26/ic_launcher.xml.
const _insetFraction = 0.16;

/// Matches ic_launcher_background in res/values/colors.xml.
const _background = [0xE7, 0xF5, 0xEF];

void main() {
  final source = File('assets/brand/saathi_icon_foreground.png');
  if (!source.existsSync()) {
    stderr.writeln('Missing ${source.path} — run tool/crop_logo.dart first.');
    exitCode = 1;
    return;
  }

  final foreground = decodePng(source.readAsBytesSync())!;
  const canvasSide = 432; // 108dp at xxxhdpi, the adaptive icon canvas

  // Apply the inset: the drawable is shrunk by 16% on every edge.
  final insetSide = (canvasSide * (1 - _insetFraction * 2)).round();
  final scaled = copyResize(
    foreground,
    width: insetSide,
    height: insetSide,
    interpolation: Interpolation.cubic,
  );

  final canvas = Image(width: canvasSide, height: canvasSide, numChannels: 3);
  fill(
    canvas,
    color: ColorRgb8(_background[0], _background[1], _background[2]),
  );

  final offset = ((canvasSide - insetSide) / 2).round();
  for (final pixel in scaled) {
    final alpha = pixel.a / 255.0;
    if (alpha <= 0) continue;
    final x = pixel.x + offset;
    final y = pixel.y + offset;
    final under = canvas.getPixel(x, y);
    int over(num src, num dst) =>
        (src * alpha + dst * (1 - alpha)).round().clamp(0, 255);
    canvas.setPixelRgb(
      x,
      y,
      over(pixel.r, under.r),
      over(pixel.g, under.g),
      over(pixel.b, under.b),
    );
  }

  // Circular mask — the tightest crop a launcher will apply.
  final radius = canvasSide / 2;
  final masked = Image(width: canvasSide, height: canvasSide, numChannels: 4);
  for (final pixel in canvas) {
    final dx = pixel.x - radius + 0.5;
    final dy = pixel.y - radius + 0.5;
    final inside = dx * dx + dy * dy <= radius * radius;
    masked.setPixelRgba(
      pixel.x,
      pixel.y,
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
      inside ? 255 : 0,
    );
  }

  Directory('build').createSync(recursive: true);
  File('build/adaptive_icon_circle.png').writeAsBytesSync(encodePng(masked));

  final small = copyResize(
    masked,
    width: 48,
    height: 48,
    interpolation: Interpolation.average,
  );
  File('build/adaptive_icon_48px.png').writeAsBytesSync(encodePng(small));

  final artworkSpan = _opaqueSpanFraction(foreground);
  stdout
    ..writeln(
      'foreground artwork fills ${(artworkSpan * 100).round()}% '
      'of its own canvas',
    )
    ..writeln(
      'after the 16% inset it fills '
      '${(artworkSpan * (1 - _insetFraction * 2) * 100).round()}% '
      'of the 108dp adaptive canvas',
    )
    ..writeln(
      '(Android crops to the central ~66%, so anything under that '
      'is safe from clipping)',
    )
    ..writeln('wrote build/adaptive_icon_circle.png')
    ..writeln('wrote build/adaptive_icon_48px.png');
}

/// Widest horizontal span containing non-transparent pixels, as a fraction of
/// image width — i.e. how much of the canvas the artwork actually covers.
double _opaqueSpanFraction(Image image) {
  var left = image.width;
  var right = 0;
  for (final pixel in image) {
    if (pixel.a <= 8) continue;
    if (pixel.x < left) left = pixel.x;
    if (pixel.x > right) right = pixel.x;
  }
  if (right <= left) return 0;
  return (right - left) / image.width;
}
