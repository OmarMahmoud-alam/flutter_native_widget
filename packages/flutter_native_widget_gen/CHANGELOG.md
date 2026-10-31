## 0.1.0

First release.

- `build_runner` builders that turn `@HomeScreenWidget` declarations into a
  typed Dart API, RemoteViews XML + Kotlin (Android) and SwiftUI + WidgetKit
  (iOS).
- Material icons become vector drawables of just the icons used; fonts are
  copied into `res/font` and the widget extension.
- CLI: `init` (adds the iOS widget extension to the Xcode project), `sync`,
  `doctor`, `clean`.
