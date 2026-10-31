import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import 'protocol.dart';

/// Native names and initial values of one widget. Generated for you.
class WidgetSpec {
  final String name;

  /// Fully qualified Android `AppWidgetProvider` class. `null` for widgets
  /// that only have iOS Lock Screen sizes.
  final String? androidProvider;

  /// Field key → initial value.
  final Map<String, String> initialValues;

  const WidgetSpec({
    required this.name,
    this.androidProvider,
    required this.initialValues,
  });
}

/// A tap on an `NWAction.callback` button.
class WidgetEvent {
  final String widget;
  final String name;
  final String? payload;
  final Uri uri;

  const WidgetEvent({
    required this.widget,
    required this.name,
    required this.payload,
    required this.uri,
  });

  static WidgetEvent? fromUri(Uri? uri) {
    if (uri == null || uriKind(uri) != UriKind.callback) return null;
    final q = uri.queryParameters;
    return WidgetEvent(
      widget: q['w'] ?? '',
      name: q['n'] ?? '',
      payload: q['p'],
      uri: uri,
    );
  }

  @override
  String toString() => 'WidgetEvent($widget.$name, payload: $payload)';
}

/// The app was opened from a widget.
class WidgetLaunch {
  /// The widget that was tapped, when known.
  final String? widget;

  /// The route given to `NWAction.openApp('/route')`, if any.
  final String? route;
  final Uri uri;

  const WidgetLaunch({this.widget, this.route, required this.uri});

  static WidgetLaunch fromUri(Uri uri) {
    if (uriKind(uri) == UriKind.open) {
      return WidgetLaunch(
        widget: uri.queryParameters['w'],
        route: uri.queryParameters['route'],
        uri: uri,
      );
    }
    return WidgetLaunch(widget: uri.queryParameters['w'], uri: uri);
  }

  @override
  String toString() => 'WidgetLaunch(widget: $widget, route: $route, $uri)';
}

/// One step of a widget timeline: from [at] on, these values are shown.
class WidgetTimelineEntry {
  final DateTime at;
  final Map<String, String?> values;

  const WidgetTimelineEntry(this.at, this.values);
}

typedef WidgetCallbackFunction = FutureOr<void> Function(WidgetEvent event);

/// A `@WidgetCallback` function and the widget it listens to.
class RegisteredCallback {
  final String? widget;
  final WidgetCallbackFunction function;

  const RegisteredCallback(this.widget, this.function);
}

/// Runtime for widgets declared with `@HomeScreenWidget`.
///
/// Call the generated `initializeHomeWidgets()` in `main`; the generated
/// `<Name>Widget` classes use this class under the hood.
abstract final class FlutterNativeWidget {
  static final Map<String, WidgetSpec> _specs = {};
  static List<RegisteredCallback> _callbacks = const [];
  static String? _appGroupId;
  static StreamSubscription<Uri?>? _clicks;
  static final _launches = StreamController<WidgetLaunch>.broadcast();
  static Future<WidgetLaunch?>? _initialLaunch;

  /// Registers the generated widget specs. Safe to call more than once.
  /// Also used by the background isolate before it runs callbacks.
  static Future<void> configure({
    String? iOSAppGroupId,
    required List<WidgetSpec> widgets,
    List<RegisteredCallback> callbacks = const [],
  }) async {
    for (final spec in widgets) {
      _specs[spec.name] = spec;
    }
    _callbacks = callbacks;
    if (iOSAppGroupId != null && iOSAppGroupId != _appGroupId) {
      _appGroupId = iOSAppGroupId;
      if (Platform.isIOS) await HomeWidget.setAppGroupId(iOSAppGroupId);
    }
  }

  /// Sets up the app side: background callbacks and launches from widgets.
  static Future<void> initialize({
    String? iOSAppGroupId,
    required List<WidgetSpec> widgets,
    List<RegisteredCallback> callbacks = const [],
    FutureOr<void> Function(Uri?)? backgroundDispatcher,
  }) async {
    await configure(
      iOSAppGroupId: iOSAppGroupId,
      widgets: widgets,
      callbacks: callbacks,
    );
    if (backgroundDispatcher != null) {
      await HomeWidget.registerInteractivityCallback(backgroundDispatcher);
    }
    _clicks ??= HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) _handleForegroundUri(uri);
    });
    _initialLaunch ??= HomeWidget.initiallyLaunchedFromHomeWidget().then((
      uri,
    ) async {
      if (uri == null) return null;
      return _handleForegroundUri(uri, emit: false);
    });
  }

  /// Every time the app is opened from a widget while running (and taps
  /// handled in the foreground).
  static Stream<WidgetLaunch> get launches => _launches.stream;

  /// How the app was started, if a widget started it.
  static Future<WidgetLaunch?> initialLaunch() =>
      _initialLaunch ?? Future.value(null);

  /// Writes [values] (field key → value, `null` removes) for [widget].
  static Future<void> save(
    String widget,
    Map<String, String?> values, {
    bool update = true,
  }) async {
    for (final MapEntry(:key, :value) in values.entries) {
      await HomeWidget.saveWidgetData<String>(storageKey(widget, key), value);
    }
    if (update) await FlutterNativeWidget.update(widget);
  }

  /// The stored value of [key], or its initial value.
  static Future<String?> read(String widget, String key) async {
    final value = await HomeWidget.getWidgetData<Object>(
      storageKey(widget, key),
    );
    return value?.toString() ?? _specs[widget]?.initialValues[key];
  }

  /// Schedules values that take over at given times, without the app
  /// running (e.g. prayer times, calendar events).
  static Future<void> saveTimeline(
    String widget,
    List<WidgetTimelineEntry> entries, {
    bool update = true,
  }) async {
    final sorted = [...entries]..sort((a, b) => a.at.compareTo(b.at));
    final json = jsonEncode([
      for (final e in sorted)
        {
          't': e.at.millisecondsSinceEpoch,
          'v': {
            for (final MapEntry(:key, :value) in e.values.entries) key: ?value,
          },
        },
    ]);
    await HomeWidget.saveWidgetData<String>(
      timelineKey(widget),
      sorted.isEmpty ? null : json,
    );
    if (update) await FlutterNativeWidget.update(widget);
  }

  /// Redraws every instance of [widget] on the home screen.
  static Future<void> update(String widget) async {
    final spec = _specs[widget];
    if (Platform.isAndroid && spec != null && spec.androidProvider == null) {
      return;
    }
    await HomeWidget.updateWidget(
      qualifiedAndroidName: spec?.androidProvider,
      iOSName: widget,
    );
  }

  static Future<void> updateAll() async {
    for (final name in _specs.keys) {
      await update(name);
    }
  }

  /// Renders [child] to a PNG in widget storage and returns its path, ready
  /// to be saved into an image field.
  ///
  /// [child] gets exactly [logicalSize]: home_widget lays it out with an
  /// unbounded height otherwise, which squashes or breaks widgets that size
  /// themselves to their parent.
  static Future<String> renderImage(
    Widget child, {
    required String widget,
    required String field,
    Size logicalSize = const Size(300, 150),
  }) {
    return HomeWidget.renderFlutterWidget(
      SizedBox.fromSize(size: logicalSize, child: child),
      key: '${storageKey(widget, field)}.render',
      logicalSize: logicalSize,
    );
  }

  /// Runs native actions and callbacks that arrive as URIs. Used by the
  /// generated background dispatcher and for iOS < 17, where buttons open
  /// the app instead of running in the widget.
  static Future<bool> handleUri(Uri? uri) async {
    if (uri == null) return false;
    switch (uriKind(uri)) {
      case UriKind.action:
        final q = uri.queryParameters;
        final widget = q['w'] ?? '';
        final key = q['k'] ?? '';
        final current = await HomeWidget.getWidgetData<Object>(
          storageKey(widget, key),
        );
        final next = applyAction(
          uri,
          current?.toString(),
          _specs[widget]?.initialValues[key] ?? '',
        );
        await save(widget, {key: next});
        return true;
      case UriKind.callback:
        final event = WidgetEvent.fromUri(uri)!;
        for (final callback in _callbacks) {
          if (callback.widget == null || callback.widget == event.widget) {
            await callback.function(event);
          }
        }
        return true;
      case UriKind.open:
      case UriKind.unknown:
        return false;
    }
  }

  static Future<WidgetLaunch?> _handleForegroundUri(
    Uri uri, {
    bool emit = true,
  }) async {
    if (await handleUri(uri)) return null;
    final launch = WidgetLaunch.fromUri(uri);
    if (emit) _launches.add(launch);
    return launch;
  }
}
