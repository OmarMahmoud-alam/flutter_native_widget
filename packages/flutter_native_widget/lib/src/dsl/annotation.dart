import 'actions.dart';
import 'fields.dart';
import 'nodes.dart';
import 'style.dart';

/// Declares a home screen widget.
///
/// ```dart
/// @HomeScreenWidget(
///   displayName: 'Counter',
///   fields: [NWField.integer('count')],
///   layout: NWColumn(children: [
///     NWText('{count}', style: NWTextStyle(size: 36)),
///     NWButton(child: NWText('+'), action: NWAction.increment('count')),
///   ]),
/// )
/// class Counter {}
/// ```
///
/// `dart run build_runner build` then generates a `CounterWidget` class with
/// typed `save`, `read` and `update` methods, plus the native code.
class HomeScreenWidget {
  /// Name used for native classes and the iOS widget kind.
  /// Defaults to the annotated class name.
  final String? name;

  /// Shown in the system widget picker.
  final String? displayName;
  final String? description;

  final List<NWSize> sizes;
  final List<NWField> fields;

  /// Choices the user makes for each copy of the widget.
  final List<NWOption> options;

  /// Downloads data for the widget on a schedule, with the app closed.
  final NWRefresh? refresh;
  final NWNode layout;

  /// Size-specific layouts that replace [layout] for those sizes.
  final NWNode? smallLayout;
  final NWNode? mediumLayout;
  final NWNode? largeLayout;

  /// Lock Screen layouts (iOS). Without one, that size uses [layout].
  final NWNode? circularLayout;
  final NWNode? rectangularLayout;
  final NWNode? inlineLayout;

  final NWColor background;
  final NWInsets padding;

  /// What a tap anywhere outside a button does. Defaults to opening the app.
  final NWAction onTap;

  const HomeScreenWidget({
    this.name,
    this.displayName,
    this.description,
    this.sizes = const [NWSize.small, NWSize.medium],
    this.fields = const [],
    this.options = const [],
    this.refresh,
    required this.layout,
    this.smallLayout,
    this.mediumLayout,
    this.largeLayout,
    this.circularLayout,
    this.rectangularLayout,
    this.inlineLayout,
    this.background = NWColor.background,
    this.padding = const NWInsets.all(12),
    this.onTap = const NWAction.openApp(),
  });
}

/// Marks a top-level function as the handler for [NWAction.callback] taps.
///
/// ```dart
/// @WidgetCallback(widget: 'Weather')
/// Future<void> refreshWeather(WidgetEvent event) async { ... }
/// ```
///
/// It runs in a background isolate, so it cannot touch your app's state.
class WidgetCallback {
  /// Only receive events from this widget. `null` receives all.
  final String? widget;

  const WidgetCallback({this.widget});
}
