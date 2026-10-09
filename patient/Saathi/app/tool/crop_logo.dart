// Cuts the square emblem out of the supplied Saathi logo lockup.
//
// The delivered logo (assets/brand/saathi_logo.jpeg, 1024x559) is a wide
// horizontal lockup: "SAATHI" wordmark on top, the hands/caduceus emblem in
// the middle, and a "Trusted Care. Together." tagline underneath. Neither the
// app's top bar nor a launcher icon can use that shape:
//
//   * a launcher icon must be square, and squashing 1.83:1 into 1:1 distorts
//   * at top-bar size the wordmark renders ~7dp tall, which is illegible
//
// So this trims to the emblem alone and centres it on a square canvas. The
// emblem is wider (~405px) than the vertical gap between the wordmark and the
// tagline (~305px), so a plain square crop would clip the hands — instead we
// crop tight to the emblem and pad out to a square.
//
// Run from the app/ directory:
//   dart run tool/crop_logo.dart
//
// Re-run this if the source logo is ever replaced.

import 'dart:io';

import 'package:image/image.dart';

/// Emblem bounds within the 1024x559 source, measured off the artwork:
/// below the "SAATHI" wordmark (ends ~y=165) and above the tagline
/// (starts ~y=485).
const _left = 310;
const _top = 168;
const _right = 715;
const _bottom = 468;

/// Breathing room around the emblem on the square canvas. Adaptive launcher
/// icons crop to roughly the central 66%, so the emblem needs margin or the
/// hands get clipped on rounded/circular icon masks.
const _marginFraction = 0.18;

void main() {
  final sourceFile = File('assets/brand/saathi_logo.jpeg');
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing ${sourceFile.path}');
    exitCode = 1;
    return;
  }

  final source = decodeImage(sourceFile.readAsBytesSync());
  if (source == null) {
    stderr.writeln('Could not decode ${sourceFile.path}');
    exitCode = 1;
    return;
  }
  stdout.writeln('source: ${source.width}x${source.height}');

  final cropWidth = _right - _left;
  final cropHeight = _bottom - _top;
  final emblem = copyCrop(
    source,
    x: _left,
    y: _top,
    width: cropWidth,
    height: cropHeight,
  );

  final longest = cropWidth > cropHeight ? cropWidth : cropHeight;
  final side = (longest * (1 + _marginFraction * 2)).round();

  final canvas = Image(width: side, height: side, numChannels: 4);
  // Fully transparent canvas — the source JPEG's white background is keyed
  // out below so the emblem sits directly on the app's cream background
  // instead of inside a visible white box.
  fill(canvas, color: ColorRgba8(0, 0, 0, 0));
  compositeImage(
    canvas,
    emblem,
    dstX: ((side - cropWidth) / 2).round(),
    dstY: ((side - cropHeight) / 2).round(),
  );
  _keyOutWhite(canvas);

  final out = File('assets/brand/saathi_emblem.png');
  out.writeAsBytesSync(encodePng(canvas));
  stdout.writeln('emblem crop: ${cropWidth}x$cropHeight');
  stdout.writeln('wrote ${out.path} (${side}x$side, transparent)');

  // ---- launcher icon sources -------------------------------------------
  //
  // Two extra outputs, because a launcher icon is not the same problem as an
  // in-app badge:
  //
  //  * Android adaptive icons crop the foreground to roughly the central 66%
  //    so the system can apply circular, squircle and other masks. The emblem
  //    fills ~74% of saathi_emblem.png, so reusing that file would clip the
  //    hands on a circular launcher. The foreground therefore gets far more
  //    padding.
  //  * iOS icons must not contain alpha, and the system applies its own
  //    rounded-corner mask, so that source is flattened onto white with a
  //    tighter crop.
  _writeIconSource(
    emblem: emblem,
    // flutter_launcher_icons applies its own 16% inset on top of this file
    // (see mipmap-anydpi-v26/ic_launcher.xml), so the two paddings compound.
    // At 0.58 the artwork ended up spanning only ~35% of the final adaptive
    // canvas — well inside Android's ~66% safe zone, but small enough to
    // look like a smudge at 48px launcher size. 0.94 lands the artwork right
    // at the edge of the safe zone instead of deep inside it.
    artworkFraction: 0.94,
    background: null,
    path: 'assets/brand/saathi_icon_foreground.png',
    note: 'Android adaptive foreground',
  );
  _writeIconSource(
    emblem: emblem,
    artworkFraction: 0.72,
    background: ColorRgb8(255, 255, 255),
    path: 'assets/brand/saathi_icon.png',
    note: 'iOS / legacy square icon',
  );

  // Flattened preview over the app's cream background, so the result can be
  // eyeballed for white fringing without a transparency checkerboard.
  // Blended by hand rather than with compositeImage, which copies raw channel
  // values here instead of honouring alpha and paints transparent pixels
  // black.
  const bg = [0xF8, 0xFA, 0xF7];
  final preview = Image(width: side, height: side, numChannels: 3);
  for (final pixel in canvas) {
    final alpha = pixel.a / 255.0;
    int over(num channel, int background) =>
        (channel * alpha + background * (1 - alpha)).round().clamp(0, 255);
    preview.setPixelRgb(
      pixel.x,
      pixel.y,
      over(pixel.r, bg[0]),
      over(pixel.g, bg[1]),
      over(pixel.b, bg[2]),
    );
  }
  final previewFile = File('build/emblem_on_cream_preview.png');
  previewFile.parent.createSync(recursive: true);
  previewFile.writeAsBytesSync(encodePng(preview));
  stdout.writeln('wrote ${previewFile.path} (preview only, not shipped)');
}

/// Writes a square icon source with the emblem occupying [artworkFraction] of
/// the canvas width, on [background] (or transparent when null).
void _writeIconSource({
  required Image emblem,
  required double artworkFraction,
  required Color? background,
  required String path,
  required String note,
}) {
  final side = (emblem.width / artworkFraction).round();
  final canvas = Image(width: side, height: side, numChannels: 4);
  fill(
    canvas,
    color: background == null
        ? ColorRgba8(0, 0, 0, 0)
        : ColorRgba8(
            background.r.toInt(),
            background.g.toInt(),
            background.b.toInt(),
            255,
          ),
  );
  compositeImage(
    canvas,
    emblem,
    dstX: ((side - emblem.width) / 2).round(),
    dstY: ((side - emblem.height) / 2).round(),
  );
  _keyOutWhite(canvas, keepOpaque: background != null);

  File(path).writeAsBytesSync(encodePng(canvas));
  stdout.writeln(
    'wrote $path (${side}x$side, '
    '${(artworkFraction * 100).round()}% artwork) — $note',
  );
}

/// Turns the source's white background transparent.
///
/// The supplied logo is a JPEG, so it has no alpha channel and its background
/// is baked-in white. Pixels are graded from opaque to transparent across a
/// luminance ramp rather than cut at a single threshold, which keeps the
/// emblem's anti-aliased edges smooth. Partially transparent pixels are then
/// un-premultiplied against white to recover their true colour — without that
/// step the edges keep a pale halo that shows up against the cream
/// background.
/// Pass [keepOpaque] for sources that must not contain alpha (iOS icons):
/// the white is still un-mixed from the edges, but nothing becomes
/// transparent.
void _keyOutWhite(Image image, {bool keepOpaque = false}) {
  const opaqueBelow = 222.0; // fully keep
  const clearAbove = 246.0; // fully drop

  if (keepOpaque) return;

  for (final pixel in image) {
    // Skip the already-transparent margin around the pasted crop. Without
    // this the margin's RGB of 0,0,0 reads as "dark, therefore keep" and the
    // emblem ends up sitting on an opaque black square.
    if (pixel.a == 0) continue;

    final r = pixel.r.toDouble();
    final g = pixel.g.toDouble();
    final b = pixel.b.toDouble();
    final luminance = 0.299 * r + 0.587 * g + 0.114 * b;

    double alpha;
    if (luminance >= clearAbove) {
      alpha = 0;
    } else if (luminance <= opaqueBelow) {
      alpha = 1;
    } else {
      alpha = (clearAbove - luminance) / (clearAbove - opaqueBelow);
    }

    if (alpha <= 0) {
      pixel.setRgba(0, 0, 0, 0);
      continue;
    }
    if (alpha >= 1) {
      pixel.a = 255;
      continue;
    }

    double unmix(double channel) =>
        ((channel - 255 * (1 - alpha)) / alpha).clamp(0, 255);

    pixel.setRgba(
      unmix(r).round(),
      unmix(g).round(),
      unmix(b).round(),
      (alpha * 255).round(),
    );
  }
}
