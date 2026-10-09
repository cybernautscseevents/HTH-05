import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WatermarkBackground extends StatefulWidget {
  final Widget child;
  final double opacity;
  final double spacing;

  const WatermarkBackground({
    super.key,
    required this.child,
    this.opacity = 0.06,
    this.spacing = 100.0,
  });

  @override
  State<WatermarkBackground> createState() => _WatermarkBackgroundState();
}

class _WatermarkBackgroundState extends State<WatermarkBackground> {
  ui.Image? _logoImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load('assets/images/saathi_logo.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _logoImage = frame.image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_logoImage != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TiledLogoPainter(
                  image: _logoImage!,
                  opacity: widget.opacity,
                  spacing: widget.spacing,
                ),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _TiledLogoPainter extends CustomPainter {
  final ui.Image image;
  final double opacity;
  final double spacing;

  static const double _logoSize = 32.0;

  _TiledLogoPainter({
    required this.image,
    required this.opacity,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..color = Color.fromRGBO(0, 0, 0, opacity);

    final srcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final spacingX = spacing;
    final spacingY = spacing;

    int row = 0;
    for (double y = -_logoSize; y < size.height + spacingY; y += spacingY) {
      final double xOffset = (row % 2 == 1) ? spacingX * 0.5 : 0.0;
      for (double x = -_logoSize + xOffset; x < size.width + spacingX; x += spacingX) {
        final dstRect = Rect.fromLTWH(x, y, _logoSize, _logoSize);
        canvas.drawImageRect(image, srcRect, dstRect, paint);
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(_TiledLogoPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.opacity != opacity ||
        oldDelegate.spacing != spacing;
  }
}
