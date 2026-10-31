import 'actions.dart';
import 'style.dart';

/// Base class of every element a home screen widget layout is made of.
///
/// Layouts must be `const`: the generator reads them at build time and turns
/// them into RemoteViews XML (Android) and SwiftUI (iOS). Anything that
/// changes at runtime goes through fields (`{key}` in text, `field:` params).
abstract class NWNode {
  const NWNode();
}

/// Places [children] vertically.
class NWColumn extends NWNode {
  final List<NWNode> children;
  final NWMainAxisAlignment mainAxisAlignment;
  final NWCrossAxisAlignment crossAxisAlignment;
  final double spacing;

  const NWColumn({
    required this.children,
    this.mainAxisAlignment = NWMainAxisAlignment.start,
    this.crossAxisAlignment = NWCrossAxisAlignment.center,
    this.spacing = 0,
  });
}

/// Places [children] horizontally. Follows the reading direction (RTL aware).
class NWRow extends NWNode {
  final List<NWNode> children;
  final NWMainAxisAlignment mainAxisAlignment;
  final NWCrossAxisAlignment crossAxisAlignment;
  final double spacing;

  const NWRow({
    required this.children,
    this.mainAxisAlignment = NWMainAxisAlignment.start,
    this.crossAxisAlignment = NWCrossAxisAlignment.center,
    this.spacing = 0,
  });
}

/// Places [children] on top of each other.
class NWStack extends NWNode {
  final List<NWNode> children;
  final NWAlignment alignment;

  const NWStack({required this.children, this.alignment = NWAlignment.center});
}

/// Sizing, padding, background and corner radius around an optional [child].
class NWBox extends NWNode {
  final NWNode? child;
  final double? width;
  final double? height;
  final NWInsets padding;
  final NWColor? color;

  /// Replaces [color] when set.
  final NWGradient? gradient;
  final NWColor? borderColor;
  final double borderWidth;
  final double radius;
  final NWAlignment alignment;

  /// Fills the space the parent gives it.
  final bool expand;

  const NWBox({
    this.child,
    this.width,
    this.height,
    this.padding = NWInsets.zero,
    this.color,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = 0,
    this.alignment = NWAlignment.center,
    this.expand = false,
  });
}

/// Takes up the remaining space in a [NWRow] or [NWColumn].
class NWSpacer extends NWNode {
  final int flex;

  const NWSpacer({this.flex = 1});
}

/// Text. `{key}` placeholders are replaced with field values natively,
/// e.g. `'Count: {count}'`.
class NWText extends NWNode {
  final String text;
  final NWTextStyle style;
  final int? maxLines;
  final NWTextAlign align;

  const NWText(
    this.text, {
    this.style = const NWTextStyle(),
    this.maxLines,
    this.align = NWTextAlign.start,
  });
}

/// Text whose parts have different styles, e.g. a bold number next to a
/// light unit:
///
/// ```dart
/// NWRichText([
///   NWSpan('{steps}', size: 28, weight: NWFontWeight.bold),
///   NWSpan(' steps', color: NWColor.secondaryLabel),
/// ])
/// ```
///
/// Each span takes what it does not set from [style].
class NWRichText extends NWNode {
  final List<NWSpan> spans;
  final NWTextStyle style;
  final int? maxLines;
  final NWTextAlign align;

  const NWRichText(
    this.spans, {
    this.style = const NWTextStyle(),
    this.maxLines,
    this.align = NWTextAlign.start,
  });
}

/// One part of an [NWRichText]. `{key}` placeholders work as in [NWText].
class NWSpan {
  final String text;
  final double? size;
  final NWFontWeight? weight;
  final NWColor? color;
  final bool? italic;

  const NWSpan(this.text, {this.size, this.weight, this.color, this.italic});
}

/// An image file whose path is stored in an image [field].
class NWImage extends NWNode {
  final String field;
  final double? width;
  final double? height;
  final NWImageFit fit;

  const NWImage({
    required this.field,
    this.width,
    this.height,
    this.fit = NWImageFit.cover,
  });
}

/// A system icon: Material Icons on Android, SF Symbols on iOS.
///
/// ```dart
/// NWIcon(Icons.favorite, size: 20, color: NWColor('#E91E63'))
/// ```
///
/// [icon] is an `IconData` from Flutter's `Icons` class. Android gets a
/// vector drawable of just that icon. iOS uses the matching SF Symbol for
/// common icons (`favorite` → `heart.fill`); for others pass [sfSymbol].
class NWIcon extends NWNode {
  /// An `IconData` from `Icons` (typed `Object` so layouts stay
  /// readable by the generator without Flutter).
  final Object icon;
  final double size;
  final NWColor? color;

  /// SF Symbol name used on iOS instead of the built-in mapping.
  final String? sfSymbol;

  const NWIcon(this.icon, {this.size = 24, this.color, this.sfSymbol});
}

/// A progress bar. [field] holds a number between 0 and [max].
class NWProgress extends NWNode {
  final String field;
  final double max;
  final NWColor? color;

  /// The unfilled part. Defaults to a light shade of the system color.
  final NWColor? trackColor;

  /// A ring of [size] instead of a horizontal bar.
  final bool circular;
  final double size;
  final double thickness;

  const NWProgress({
    required this.field,
    this.max = 1,
    this.color,
    this.trackColor,
  }) : circular = false,
       size = 0,
       thickness = 0;

  /// A ring like the Activity rings, starting at the top and filling
  /// clockwise. Put an [NWStack] around it to show text in the middle.
  const NWProgress.circular({
    required this.field,
    this.max = 1,
    this.color,
    this.trackColor,
    this.size = 56,
    this.thickness = 6,
  }) : circular = true;
}

/// The current time, kept up to date by the system even while the app is
/// closed (Android `TextClock`, iOS timeline / timer text).
///
/// On iOS, [showSeconds] uses a timer counting from midnight, which always
/// shows 24-hour time.
class NWClock extends NWNode {
  final bool showSeconds;

  /// `null` follows the device setting.
  final bool? use24Hour;
  final NWTextStyle style;
  final NWTextAlign align;

  const NWClock({
    this.showSeconds = false,
    this.use24Hour,
    this.style = const NWTextStyle(size: 40, weight: NWFontWeight.semibold),
    this.align = NWTextAlign.start,
  });
}

/// A clock face with hands, kept up to date by the system.
///
/// - Android: the system `AnalogClock`. The [secondHand] ticks every second
///   on Android 12+; older versions show hour and minute hands only.
/// - iOS: drawn with SwiftUI and refreshed every minute. iOS widgets cannot
///   animate, so there is **no second hand on iOS**.
class NWAnalogClock extends NWNode {
  /// Diameter in dp/pt.
  final double size;
  final NWColor face;
  final NWColor? border;
  final NWColor ticks;
  final NWColor hands;

  /// Color of the second hand; `null` hides it.
  final NWColor? secondHand;

  /// 12 marks around the face; `false` shows only the four quarters.
  final bool allTicks;

  const NWAnalogClock({
    this.size = 120,
    this.face = const NWColor('#FFFFFF', dark: '#1C1C1E'),
    this.border,
    this.ticks = const NWColor('#8E8E93'),
    this.hands = NWColor.label,
    this.secondHand,
    this.allTicks = true,
  });
}

/// A formatted date: today's date when [field] is null (updated by the
/// system at midnight), otherwise the date stored in a dateTime field.
///
/// [pattern] uses ICU/`SimpleDateFormat` symbols, e.g. `'EEEE d MMMM'`.
class NWDateText extends NWNode {
  final String pattern;
  final String? field;
  final NWTextStyle style;
  final NWTextAlign align;

  const NWDateText({
    this.pattern = 'EEEE d MMMM',
    this.field,
    this.style = const NWTextStyle(),
    this.align = NWTextAlign.start,
  });
}

/// A live timer towards (or since) the time stored in a dateTime [field].
/// Counts down before that moment and up after it. Ticks every second with
/// the app closed (Android `Chronometer`, iOS `Text(_, style: .timer)`).
class NWTimer extends NWNode {
  final String field;
  final NWTextStyle style;
  final NWTextAlign align;

  const NWTimer({
    required this.field,
    this.style = const NWTextStyle(monospacedDigits: true),
    this.align = NWTextAlign.start,
  });
}

/// Makes [child] tappable.
class NWButton extends NWNode {
  final NWNode child;
  final NWAction action;

  const NWButton({required this.child, required this.action});
}

/// Shows [child] when [condition] holds, otherwise [orElse].
class NWIf extends NWNode {
  final NWCondition condition;
  final NWNode child;
  final NWNode? orElse;

  const NWIf({required this.condition, required this.child, this.orElse});
}

/// A list of [count] items that scrolls on Android 12+. Like [NWRepeat],
/// `#` in field keys inside [child] is the item index (`{title#}`), so its
/// fields are declared with `repeat: count`.
///
/// iOS widgets cannot scroll, and neither can Android before 12: there the
/// items are laid out in a column and the ones that do not fit are cut off.
/// Taps inside items can run native actions and callbacks, not open the app
/// (use the widget's `onTap` for that).
class NWList extends NWNode {
  final int count;
  final NWNode child;
  final double spacing;

  const NWList({required this.count, required this.child, this.spacing = 0});
}

/// Repeats [child] [count] times. Inside it, `#` in field keys is replaced
/// with the index: `{title#}` becomes `{title0}`, `{title1}`, ...
class NWRepeat extends NWNode {
  final int count;
  final NWNode child;

  /// Laid out vertically unless [horizontal].
  final bool horizontal;
  final double spacing;

  const NWRepeat({
    required this.count,
    required this.child,
    this.horizontal = false,
    this.spacing = 0,
  });
}
