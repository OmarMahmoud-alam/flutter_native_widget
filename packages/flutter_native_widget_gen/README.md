# flutter_native_widget_gen

Code generator and CLI for
[flutter_native_widget](https://pub.dev/packages/flutter_native_widget).
Full guide and examples: [flutter-native-widget.vercel.app](https://flutter-native-widget.vercel.app).

- `build_runner` builders: read `@HomeScreenWidget` / `@WidgetCallback`, write
  the typed Dart API and the native Android (RemoteViews + Kotlin) and iOS
  (WidgetKit + SwiftUI) code.
- CLI: `init`, `sync`, `doctor`, `clean`.

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  flutter_native_widget_gen: ^0.1.1
```

## How it works

```
@HomeScreenWidget (const Dart) ──analyzer──► IR (JSON) ──┬─► Dart part + registry
                                                         ├─► Android: layouts, Kotlin, manifest
                                                         └─► iOS: SwiftUI, App Intents
```

The IR is cached in `.dart_tool/flutter_native_widget/ir.json` so `sync` can
rewrite the native code without a full build. `project.pbxproj` is edited with
a Dart parser that writes Xcode's own format (an untouched Flutter project
round-trips byte for byte).

Set `sync: false` to only generate Dart:

```yaml
# build.yaml in your app
targets:
  $default:
    builders:
      flutter_native_widget_gen:native:
        options:
          sync: false
```

## Development

```bash
dart test
```
