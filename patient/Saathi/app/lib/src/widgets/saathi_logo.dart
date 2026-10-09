import 'package:flutter/material.dart';

import '../theme.dart';

/// The Saathi brand mark for the top bar.
///
/// Renders `assets/brand/saathi_emblem.png` — the square emblem cut out of the
/// supplied logo lockup by `tool/crop_logo.dart`. The full lockup is not used
/// here: its "SAATHI" wordmark occupies only ~16% of the artwork's height, so
/// at this size it would render around 7dp tall and be unreadable, and its
/// "Trusted Care. Together." tagline smaller still. The emblem carries the
/// brand at small sizes; the name is set as live text beside it.
class SaathiLogo extends StatelessWidget {
  const SaathiLogo({
    super.key,
    this.size = 36,
    this.showWordmark = true,
    this.fillEmblemFrame = false,
    this.wordmarkFontSize = 25,
  });

  final double size;
  final bool showWordmark;
  final bool fillEmblemFrame;
  final double wordmarkFontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fillEmblemFrame)
          SizedBox.square(
            dimension: size,
            child: ClipRect(
              child: OverflowBox(
                minWidth: size * 1.47,
                maxWidth: size * 1.47,
                minHeight: size * 1.47,
                maxHeight: size * 1.47,
                child: _EmblemImage(size: size * 1.47),
              ),
            ),
          )
        else
          _EmblemImage(size: size),
        if (showWordmark) ...[
          const SizedBox(width: 8),
          // Flexible so the wordmark can never push the row past its bounds
          // at large system font scales — without it the header overflowed by
          // hundreds of pixels at 2x.
          Flexible(
            child: Text(
              'Saathi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.saathiColors.brand,
                fontWeight: FontWeight.w900,
                // Deliberately not proportional to [size]. The emblem was
                // enlarged for presence; scaling the wordmark with it would
                // make the name overpower the mark and crowd the language
                // pill beside it.
                fontSize: wordmarkFontSize,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmblemImage extends StatelessWidget {
  const _EmblemImage({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/saathi_emblem.png',
      height: size,
      width: size,
      fit: BoxFit.contain,
      // Announced by the wordmark beside it; avoids a screen reader saying
      // the brand name twice.
      excludeFromSemantics: true,
      filterQuality: FilterQuality.medium,
    );
  }
}
