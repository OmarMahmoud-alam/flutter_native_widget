enum NWActionKind {
  openApp,
  increment,
  decrement,
  toggle,
  set,
  cycle,
  callback,
}

/// What happens when the user taps an [NWButton] or the widget itself.
///
/// [increment], [decrement], [toggle], [set] and [cycle] are **native
/// actions**: the generated widget code changes the stored value and redraws
/// on its own, without starting Dart. Use [callback] when the reaction needs
/// your Dart code (network, database, ...).
///
/// | Action      | Android | iOS 17+          | iOS 14–16          |
/// |-------------|---------|------------------|--------------------|
/// | openApp     | ✅      | ✅               | ✅                 |
/// | native      | ✅      | ✅ (App Intent)  | opens the app, which applies it |
/// | callback    | ✅      | ✅ (App Intent)  | opens the app, which runs it    |
class NWAction {
  final NWActionKind kind;

  /// The field the action changes, or the callback name.
  final String key;

  /// For [set]: the new value. For [openApp]: the URL or route.
  final String? value;

  /// For [cycle]: the values to step through.
  final List<String>? values;

  final int by;
  final int? min;
  final int? max;

  /// Opens the app. [url] arrives in `FlutterNativeWidget.launches`;
  /// defaults to the widget's name.
  const NWAction.openApp([String? url])
    : kind = NWActionKind.openApp,
      key = '',
      value = url,
      values = null,
      by = 1,
      min = null,
      max = null;

  const NWAction.increment(this.key, {this.by = 1, this.min, this.max})
    : kind = NWActionKind.increment,
      value = null,
      values = null;

  const NWAction.decrement(this.key, {this.by = 1, this.min, this.max})
    : kind = NWActionKind.decrement,
      value = null,
      values = null;

  const NWAction.toggle(this.key)
    : kind = NWActionKind.toggle,
      value = null,
      values = null,
      by = 1,
      min = null,
      max = null;

  const NWAction.set(this.key, String this.value)
    : kind = NWActionKind.set,
      values = null,
      by = 1,
      min = null,
      max = null;

  /// Moves the field to the next entry of [values], wrapping around.
  const NWAction.cycle(this.key, List<String> this.values)
    : kind = NWActionKind.cycle,
      value = null,
      by = 1,
      min = null,
      max = null;

  /// Runs your `@WidgetCallback` functions in a background isolate.
  /// [payload] is passed along as `WidgetEvent.payload`.
  const NWAction.callback(this.key, {String? payload})
    : kind = NWActionKind.callback,
      value = payload,
      values = null,
      by = 1,
      min = null,
      max = null;
}

enum NWConditionKind { isTrue, isFalse, isEmpty, notEmpty, equals, greaterThan }

/// A condition on a stored value, evaluated by the native widget.
class NWCondition {
  final NWConditionKind kind;
  final String key;
  final String? value;

  const NWCondition.isTrue(this.key)
    : kind = NWConditionKind.isTrue,
      value = null;

  const NWCondition.isFalse(this.key)
    : kind = NWConditionKind.isFalse,
      value = null;

  const NWCondition.isEmpty(this.key)
    : kind = NWConditionKind.isEmpty,
      value = null;

  const NWCondition.notEmpty(this.key)
    : kind = NWConditionKind.notEmpty,
      value = null;

  const NWCondition.equals(this.key, String this.value)
    : kind = NWConditionKind.equals;

  /// Numeric comparison: the field's value is greater than [value].
  const NWCondition.greaterThan(this.key, String this.value)
    : kind = NWConditionKind.greaterThan;
}
