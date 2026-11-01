## 0.1.1

- Link the website (guide, video, examples) from pub.dev.
- README: when to use home_widget directly instead of this package.
- Screenshots and an example page on pub.dev.

## 0.1.0

First release. Home screen widgets for Android and iOS, written in Dart.

- Layout DSL: `NWColumn`, `NWRow`, `NWStack`, `NWBox`, `NWSpacer`, `NWText`,
  `NWRichText`, `NWImage`, `NWIcon`, `NWProgress` (bar and ring), `NWClock`,
  `NWAnalogClock`, `NWDateText`, `NWTimer`, `NWButton`, `NWIf`, `NWRepeat`,
  `NWList` (scrolls on Android 12+).
- Styles: light/dark colors, gradients, borders, radius, padding, font
  weights, italic, tabular digits, custom font files.
- Typed fields, timelines, Flutter widgets rendered to images.
- Native actions (increment, toggle, set, cycle) and Dart callbacks that run
  without opening the app.
- Per-copy options chosen by the user (`NWOption`) and data downloaded on a
  schedule with the app closed (`NWRefresh`).
- iOS Lock Screen sizes (`circular`, `rectangular`, `inline`).
