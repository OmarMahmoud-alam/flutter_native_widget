/// A color for generated native code, with an optional dark-mode variant.
///
/// ```dart
/// NWColor('#1E88E5', dark: '#90CAF9')
/// ```
class NWColor {
  /// `#RRGGBB` or `#AARRGGBB`.
  final String light;

  /// Used when the system is in dark mode. Falls back to [light].
  final String? dark;

  const NWColor(this.light, {this.dark});

  static const white = NWColor('#FFFFFF');
  static const black = NWColor('#000000');
  static const transparent = NWColor('#00000000');

  /// Default text color: near-black in light mode, near-white in dark mode.
  static const label = NWColor('#1C1C1E', dark: '#F2F2F7');

  /// Secondary text color.
  static const secondaryLabel = NWColor('#6C6C70', dark: '#AEAEB2');

  /// Default widget background.
  static const background = NWColor('#FFFFFF', dark: '#1C1C1E');
}

/// A linear gradient for [NWBox] backgrounds.
///
/// Android draws gradients with up to three colors and angles in steps of
/// 45°, so [begin]/[end] are snapped to the nearest such direction there.
class NWGradient {
  /// Two or three colors.
  final List<NWColor> colors;
  final NWAlignment begin;
  final NWAlignment end;

  const NWGradient({
    required this.colors,
    this.begin = NWAlignment.topStart,
    this.end = NWAlignment.bottomEnd,
  });
}

enum NWFontWeight { light, regular, medium, semibold, bold }

enum NWTextAlign { start, center, end }

class NWTextStyle {
  final double size;
  final NWFontWeight weight;
  final NWColor? color;
  final bool italic;

  /// Use tabular (monospaced) digits so numbers do not jump around.
  final bool monospacedDigits;

  /// A `.ttf` or `.otf` file, relative to the project root, e.g.
  /// `'assets/fonts/Cairo-Bold.ttf'`. Pick the file of the weight you want;
  /// [weight] is ignored. Android 8+; older versions use the system font.
  final String? font;

  const NWTextStyle({
    this.size = 14,
    this.weight = NWFontWeight.regular,
    this.color,
    this.italic = false,
    this.monospacedDigits = false,
    this.font,
  });
}

class NWInsets {
  final double start;
  final double top;
  final double end;
  final double bottom;

  const NWInsets.only({
    this.start = 0,
    this.top = 0,
    this.end = 0,
    this.bottom = 0,
  });

  const NWInsets.all(double value)
    : start = value,
      top = value,
      end = value,
      bottom = value;

  const NWInsets.symmetric({double horizontal = 0, double vertical = 0})
    : start = horizontal,
      end = horizontal,
      top = vertical,
      bottom = vertical;

  static const zero = NWInsets.all(0);
}

enum NWMainAxisAlignment { start, center, end, spaceBetween }

enum NWCrossAxisAlignment { start, center, end, stretch }

enum NWAlignment {
  topStart,
  topCenter,
  topEnd,
  centerStart,
  center,
  centerEnd,
  bottomStart,
  bottomCenter,
  bottomEnd,
}

enum NWImageFit { contain, cover, fill }

/// The sizes a widget supports.
///
/// | Size        | iOS family           | Android (approx. cells) |
/// |-------------|----------------------|-------------------------|
/// | small       | systemSmall          | 2 × 2                   |
/// | medium      | systemMedium         | 4 × 2                   |
/// | large       | systemLarge          | 4 × 4                   |
/// | circular    | accessoryCircular    | —                       |
/// | rectangular | accessoryRectangular | —                       |
/// | inline      | accessoryInline      | —                       |
///
/// The last three are iOS Lock Screen widgets (iOS 16+). The system tints
/// them, draws no background and ignores `padding`. `inline` shows only the
/// first text (or clock, date, timer) of its layout. Android has no Lock
/// Screen widgets, so they are skipped there.
enum NWSize { small, medium, large, circular, rectangular, inline }
