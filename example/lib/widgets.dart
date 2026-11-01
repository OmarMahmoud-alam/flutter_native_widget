import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_native_widget/flutter_native_widget.dart';

part 'widgets.fnw.dart';

const _accent = NWColor('#1E88E5', dark: '#90CAF9');
const _muted = NWColor.secondaryLabel;

/// 1. A clock the system keeps ticking while the app is closed.
@HomeScreenWidget(
  displayName: 'Clock',
  description: 'Live time and date',
  sizes: [NWSize.small, NWSize.medium, NWSize.circular, NWSize.inline],
  // Lock Screen (iOS): an analog clock, and the date above the time.
  circularLayout: NWAnalogClock(size: 64),
  inlineLayout: NWDateText(pattern: 'EEE d MMM'),
  layout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.start,
    mainAxisAlignment: NWMainAxisAlignment.center,
    spacing: 4,
    children: [
      NWClock(),
      NWDateText(
        pattern: 'EEEE d MMMM',
        style: NWTextStyle(size: 14, color: _muted),
      ),
    ],
  ),
)
class Clock {}

/// 1b. Analog and digital together on a gradient. The second hand ticks on
/// Android 12+; iOS shows hour and minute hands.
@HomeScreenWidget(
  displayName: 'Watch face',
  description: 'Analog and digital clocks together',
  sizes: [NWSize.medium],
  padding: NWInsets.zero,
  layout: NWBox(
    expand: true,
    padding: NWInsets.all(14),
    gradient: NWGradient(
      colors: [
        NWColor('#1E3A8A', dark: '#0B1229'),
        NWColor('#7C3AED', dark: '#3B0764'),
      ],
    ),
    child: NWRow(
      spacing: 18,
      children: [
        NWAnalogClock(
          size: 112,
          face: NWColor('#FFFFFF', dark: '#111827'),
          border: NWColor('#C7D2FE', dark: '#4C1D95'),
          ticks: NWColor('#6366F1', dark: '#A5B4FC'),
          hands: NWColor('#111827', dark: '#F9FAFB'),
          secondHand: NWColor('#F97316'),
        ),
        NWColumn(
          crossAxisAlignment: NWCrossAxisAlignment.start,
          spacing: 2,
          children: [
            NWText(
              'CAIRO',
              style: NWTextStyle(
                size: 11,
                weight: NWFontWeight.semibold,
                color: NWColor('#C7D2FE'),
              ),
            ),
            NWClock(
              style: NWTextStyle(
                size: 38,
                weight: NWFontWeight.bold,
                color: NWColor.white,
                monospacedDigits: true,
              ),
            ),
            NWDateText(
              pattern: 'EEEE d MMMM',
              style: NWTextStyle(size: 13, color: NWColor('#E0E7FF')),
            ),
            NWBox(
              padding: NWInsets.symmetric(horizontal: 8, vertical: 3),
              radius: 10,
              color: NWColor('#33FFFFFF'),
              borderColor: NWColor('#66FFFFFF'),
              child: NWText(
                'Have a good day',
                style: NWTextStyle(size: 11, color: NWColor.white),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
)
class WatchFace {}

/// 2. Buttons that change data without opening the app (native actions).
@HomeScreenWidget(
  displayName: 'Counter',
  description: 'Tap + and − right on the home screen',
  fields: [NWField.integer('count')],
  layout: NWColumn(
    mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
    children: [
      NWText('Counter', style: NWTextStyle(size: 13, color: _muted)),
      NWText(
        '{count}',
        style: NWTextStyle(
          size: 44,
          weight: NWFontWeight.bold,
          monospacedDigits: true,
        ),
      ),
      NWRow(
        spacing: 12,
        children: [
          NWButton(
            action: NWAction.decrement('count', min: 0),
            child: NWBox(
              width: 44,
              height: 36,
              radius: 18,
              color: _accent,
              child: NWText(
                '−',
                style: NWTextStyle(size: 20, color: NWColor.white),
              ),
            ),
          ),
          NWButton(
            action: NWAction.increment('count', max: 99),
            child: NWBox(
              width: 44,
              height: 36,
              radius: 18,
              color: _accent,
              child: NWText(
                '+',
                style: NWTextStyle(size: 20, color: NWColor.white),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
  onTap: NWAction.openApp('/counter'),
)
class Counter {}

/// 3. A list with checkboxes that toggle on the home screen.
@HomeScreenWidget(
  displayName: 'Tasks',
  description: 'Today\'s tasks',
  sizes: [NWSize.medium, NWSize.large],
  fields: [
    NWField.string('title', repeat: 4),
    NWField.boolean('done', repeat: 4),
  ],
  layout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      NWText(
        'Tasks',
        style: NWTextStyle(size: 15, weight: NWFontWeight.semibold),
      ),
      NWRepeat(
        count: 4,
        spacing: 4,
        child: NWIf(
          condition: NWCondition.notEmpty('title#'),
          child: NWButton(
            action: NWAction.toggle('done#'),
            child: NWRow(
              spacing: 8,
              children: [
                NWIf(
                  condition: NWCondition.isTrue('done#'),
                  child: NWText(
                    '☑',
                    style: NWTextStyle(size: 18, color: _accent),
                  ),
                  orElse: NWText(
                    '☐',
                    style: NWTextStyle(size: 18, color: _muted),
                  ),
                ),
                NWText('{title#}', maxLines: 1),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
  onTap: NWAction.openApp('/tasks'),
)
class Tasks {}

/// 4. Prayer times: the app saves the whole day as a timeline once; the
/// widget switches to the next prayer on its own.
@HomeScreenWidget(
  displayName: 'مواقيت الصلاة',
  description: 'الصلاة الجاية والوقت المتبقي',
  sizes: [NWSize.small, NWSize.medium, NWSize.rectangular, NWSize.inline],
  rectangularLayout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.start,
    children: [
      NWText('{next}', style: NWTextStyle(size: 17, weight: NWFontWeight.bold)),
      NWTimer(field: 'nextAt', style: NWTextStyle(monospacedDigits: true)),
    ],
  ),
  inlineLayout: NWText('🕌 {next}'),
  fields: [
    NWField.string('next', initial: '—'),
    NWField.dateTime('nextAt'),
    NWField.string('city', initial: 'القاهرة'),
  ],
  layout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.start,
    mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
    children: [
      NWText('{city}', style: NWTextStyle(size: 13, color: _muted)),
      NWColumn(
        crossAxisAlignment: NWCrossAxisAlignment.start,
        children: [
          NWText('الصلاة الجاية', style: NWTextStyle(size: 13, color: _muted)),
          NWText(
            '{next}',
            style: NWTextStyle(size: 26, weight: NWFontWeight.bold),
          ),
        ],
      ),
      NWTimer(
        field: 'nextAt',
        style: NWTextStyle(size: 20, color: _accent, monospacedDigits: true),
      ),
    ],
  ),
  background: NWColor('#FFF8E1', dark: '#2B2410'),
)
class PrayerTimes {}

/// 5. Countdown to an event; switches to "done" through a timeline entry.
@HomeScreenWidget(
  displayName: 'Countdown',
  description: 'Time left until your event',
  sizes: [NWSize.small],
  fields: [
    NWField.string('event', initial: 'Set an event in the app'),
    NWField.dateTime('at'),
    NWField.boolean('finished'),
  ],
  layout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.start,
    mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
    children: [
      NWText(
        '{event}',
        maxLines: 2,
        style: NWTextStyle(size: 15, weight: NWFontWeight.semibold),
      ),
      NWIf(
        condition: NWCondition.isTrue('finished'),
        child: NWText(
          '🎉 It\'s time!',
          style: NWTextStyle(size: 22, weight: NWFontWeight.bold),
        ),
        orElse: NWTimer(
          field: 'at',
          style: NWTextStyle(
            size: 26,
            weight: NWFontWeight.bold,
            monospacedDigits: true,
          ),
        ),
      ),
    ],
  ),
  background: NWColor('#EDE7F6', dark: '#221B33'),
)
class Countdown {}

/// 6. Music player: native play/pause, Dart callbacks for prev/next and an
/// album cover image.
@HomeScreenWidget(
  displayName: 'Now Playing',
  description: 'Control playback from the home screen',
  sizes: [NWSize.medium],
  fields: [
    NWField.string('title', initial: 'Nothing playing'),
    NWField.string('artist'),
    NWField.boolean('playing'),
    NWField.image('cover'),
  ],
  layout: NWRow(
    spacing: 12,
    children: [
      NWImage(field: 'cover', width: 72, height: 72),
      NWColumn(
        crossAxisAlignment: NWCrossAxisAlignment.start,
        spacing: 2,
        children: [
          NWText(
            '{title}',
            maxLines: 1,
            style: NWTextStyle(size: 16, weight: NWFontWeight.semibold),
          ),
          NWText(
            '{artist}',
            maxLines: 1,
            style: NWTextStyle(size: 13, color: _muted),
          ),
          NWRow(
            spacing: 18,
            children: [
              NWButton(
                action: NWAction.callback('previous'),
                child: NWText('⏮', style: NWTextStyle(size: 22)),
              ),
              NWButton(
                action: NWAction.toggle('playing'),
                child: NWIf(
                  condition: NWCondition.isTrue('playing'),
                  child: NWText('⏸', style: NWTextStyle(size: 22)),
                  orElse: NWText('▶️', style: NWTextStyle(size: 22)),
                ),
              ),
              NWButton(
                action: NWAction.callback('next'),
                child: NWText('⏭', style: NWTextStyle(size: 22)),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
)
class NowPlaying {}

/// 7. Quick actions: several deep links in one widget.
@HomeScreenWidget(
  displayName: 'Quick actions',
  description: 'Jump straight into the app',
  sizes: [NWSize.medium],
  layout: NWRow(
    mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
    children: [
      NWButton(action: NWAction.openApp('/counter'), child: _counterTile),
      NWButton(action: NWAction.openApp('/tasks'), child: _tasksTile),
      NWButton(action: NWAction.openApp('/music'), child: _musicTile),
      NWButton(action: NWAction.openApp('/chart'), child: _chartTile),
    ],
  ),
)
class QuickActions {}

// Pieces of a layout can be reused as top-level consts.
const _counterTile = NWColumn(
  spacing: 4,
  children: [
    NWText('🔢', style: NWTextStyle(size: 28)),
    NWText('Counter', style: NWTextStyle(size: 12)),
  ],
);
const _tasksTile = NWColumn(
  spacing: 4,
  children: [
    NWText('✅', style: NWTextStyle(size: 28)),
    NWText('Tasks', style: NWTextStyle(size: 12)),
  ],
);
const _musicTile = NWColumn(
  spacing: 4,
  children: [
    NWText('🎵', style: NWTextStyle(size: 28)),
    NWText('Music', style: NWTextStyle(size: 12)),
  ],
);
const _chartTile = NWColumn(
  spacing: 4,
  children: [
    NWText('📈', style: NWTextStyle(size: 28)),
    NWText('Chart', style: NWTextStyle(size: 12)),
  ],
);

/// 8. A chart drawn with Flutter, shown as an image (snapshot mode).
@HomeScreenWidget(
  displayName: 'Steps',
  description: 'This week, drawn by Flutter',
  sizes: [NWSize.medium],
  fields: [
    NWField.image('chart'),
    NWField.string('total', initial: '0'),
  ],
  layout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      NWRow(
        children: [
          NWText(
            'Steps this week',
            style: NWTextStyle(size: 13, color: _muted),
          ),
          NWSpacer(),
          NWText(
            '{total}',
            style: NWTextStyle(size: 13, weight: NWFontWeight.semibold),
          ),
        ],
      ),
      NWBox(
        expand: true,
        child: NWImage(field: 'chart', fit: NWImageFit.contain),
      ),
    ],
  ),
)
class Steps {}

/// 9. Photo album: the app renders the photos once and saves them as a
/// timeline; the widget shows the next one every hour on its own.
@HomeScreenWidget(
  displayName: 'Photo album',
  description: 'A new photo every hour',
  sizes: [NWSize.small, NWSize.large],
  fields: [NWField.image('photo'), NWField.string('caption')],
  padding: NWInsets.zero,
  layout: NWStack(
    children: [
      NWBox(expand: true, child: NWImage(field: 'photo')),
      NWBox(
        expand: true,
        padding: NWInsets.all(10),
        alignment: NWAlignment.bottomStart,
        child: NWBox(
          padding: NWInsets.symmetric(horizontal: 8, vertical: 4),
          radius: 8,
          color: NWColor('#66000000'),
          child: NWText(
            '{caption}',
            maxLines: 1,
            style: NWTextStyle(size: 12, color: NWColor.white),
          ),
        ),
      ),
    ],
  ),
  background: NWColor('#263238'),
  onTap: NWAction.openApp('/album'),
)
class PhotoAlbum {}

const _orange = NWColor('#FF6B00', dark: '#FF9F0A');
const _green = NWColor('#30B94D', dark: '#30D158');

/// 10. Rings, system icons, rich text and a custom font.
@HomeScreenWidget(
  displayName: 'Activity',
  description: 'Rings, icons and styled text',
  sizes: [NWSize.small],
  fields: [
    NWField.integer('steps', initial: '6240'),
    NWField.integer('goal', initial: '10000'),
    NWField.decimal('move', initial: '0.62'),
    NWField.decimal('exercise', initial: '0.35'),
  ],
  layout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.start,
    mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
    children: [
      NWRow(
        spacing: 4,
        children: [
          NWIcon(Icons.local_fire_department, size: 16, color: _orange),
          NWText(
            'ACTIVITY',
            style: NWTextStyle(
              size: 13,
              color: _orange,
              font: 'assets/fonts/Roboto-Black.ttf',
            ),
          ),
        ],
      ),
      NWStack(
        children: [
          NWProgress.circular(
            field: 'move',
            size: 66,
            thickness: 9,
            color: _orange,
          ),
          NWProgress.circular(
            field: 'exercise',
            size: 42,
            thickness: 9,
            color: _green,
          ),
          NWIcon(Icons.directions_walk, size: 14, color: _muted),
        ],
      ),
      NWRichText([
        NWSpan('{steps}', size: 20, weight: NWFontWeight.bold),
        NWSpan(' / {goal}', color: _muted),
      ], style: NWTextStyle(size: 12, monospacedDigits: true)),
    ],
  ),
)
class Activity {}

/// 11. A list that scrolls on Android 12+ and downloads its items every
/// 30 minutes, with the app closed.
@HomeScreenWidget(
  displayName: 'News',
  description: 'Scrolls on Android, refreshes from the web',
  sizes: [NWSize.medium, NWSize.large],
  fields: [
    NWField.string('title', repeat: 10),
    NWField.boolean('read', repeat: 10),
  ],
  refresh: NWRefresh(
    url: 'https://dummyjson.com/posts?limit=10',
    values: {'title#': 'posts.#.title'},
  ),
  layout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      NWRow(
        spacing: 6,
        children: [
          NWIcon(Icons.trending_up, size: 16, color: _accent),
          NWText(
            'Latest',
            style: NWTextStyle(size: 15, weight: NWFontWeight.semibold),
          ),
        ],
      ),
      NWList(
        count: 10,
        spacing: 8,
        child: NWIf(
          condition: NWCondition.notEmpty('title#'),
          child: NWButton(
            action: NWAction.toggle('read#'),
            child: NWRow(
              spacing: 8,
              children: [
                NWIf(
                  condition: NWCondition.isTrue('read#'),
                  child: NWIcon(Icons.check_circle, size: 16, color: _green),
                  orElse: NWIcon(
                    Icons.radio_button_unchecked,
                    size: 16,
                    color: _muted,
                  ),
                ),
                NWText('{title#}', maxLines: 1),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
)
class News {}

/// 12. Each copy shows the city the user picked; the weather for it is
/// downloaded natively every 30 minutes.
@HomeScreenWidget(
  displayName: 'Weather',
  description: 'Pick a city',
  sizes: [NWSize.small],
  fields: [
    NWField.string('temp', initial: '--'),
    NWField.string('feels', initial: '--'),
    NWField.string('sky'),
  ],
  options: [
    NWOption(
      'city',
      label: 'City',
      choices: ['Cairo', 'Alexandria', 'London', 'Tokyo'],
    ),
  ],
  refresh: NWRefresh(
    url: 'https://wttr.in/{city}?format=j1',
    values: {
      'temp': 'current_condition.0.temp_C',
      'feels': 'current_condition.0.FeelsLikeC',
      'sky': 'current_condition.0.weatherDesc.0.value',
    },
  ),
  padding: NWInsets.zero,
  layout: NWBox(
    expand: true,
    padding: NWInsets.all(14),
    alignment: NWAlignment.topStart,
    gradient: NWGradient(
      colors: [
        NWColor('#2F80ED'),
        NWColor('#56CCF2', dark: '#1E3A8A'),
      ],
    ),
    child: NWColumn(
      crossAxisAlignment: NWCrossAxisAlignment.start,
      mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
      children: [
        NWRow(
          spacing: 4,
          children: [
            NWIcon(Icons.location_on, size: 14, color: NWColor.white),
            NWText(
              '{city}',
              style: NWTextStyle(
                size: 14,
                weight: NWFontWeight.semibold,
                color: NWColor.white,
              ),
            ),
          ],
        ),
        NWRichText([
          NWSpan('{temp}', size: 44, weight: NWFontWeight.light),
          NWSpan('°C', size: 18),
        ], style: NWTextStyle(color: NWColor.white)),
        NWColumn(
          crossAxisAlignment: NWCrossAxisAlignment.start,
          children: [
            NWText(
              '{sky}',
              maxLines: 1,
              style: NWTextStyle(size: 12, color: NWColor.white),
            ),
            NWText(
              'Feels like {feels}°',
              style: NWTextStyle(size: 11, color: NWColor('#E0F2FE')),
            ),
          ],
        ),
      ],
    ),
  ),
)
class Weather {}

const _water = NWColor('#0284C7', dark: '#38BDF8');

/// 13. Water tracker: a different layout per size, progress as a ring and as
/// a bar, and native buttons that add a glass, reset or change the cup size.
@HomeScreenWidget(
  displayName: 'Water',
  description: 'Glasses of water today',
  sizes: [NWSize.small, NWSize.medium],
  fields: [
    NWField.integer('glasses'),
    NWField.string('cup', initial: '250 ml'),
  ],
  smallLayout: NWColumn(
    mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
    children: [
      NWText('Water', style: NWTextStyle(size: 13, color: _water)),
      NWStack(
        children: [
          NWProgress.circular(
            field: 'glasses',
            max: 8,
            size: 74,
            thickness: 10,
            color: _water,
          ),
          NWText(
            '{glasses}',
            style: NWTextStyle(
              size: 24,
              weight: NWFontWeight.bold,
              monospacedDigits: true,
            ),
          ),
        ],
      ),
      NWButton(action: NWAction.increment('glasses', max: 8), child: _addGlass),
    ],
  ),
  layout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.stretch,
    mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
    children: [
      NWRow(
        children: [
          NWIcon(Icons.water_drop, size: 18, color: _water),
          NWSpacer(),
          NWButton(
            action: NWAction.cycle('cup', ['250 ml', '330 ml', '500 ml']),
            child: NWBox(
              padding: NWInsets.symmetric(horizontal: 8, vertical: 3),
              radius: 10,
              borderColor: _water,
              child: NWText(
                'Cup: {cup}',
                style: NWTextStyle(size: 12, color: _water),
              ),
            ),
          ),
        ],
      ),
      NWIf(
        condition: NWCondition.greaterThan('glasses', '7'),
        child: NWText(
          'Goal reached 🎉',
          style: NWTextStyle(size: 22, weight: NWFontWeight.bold),
        ),
        orElse: NWRichText([
          NWSpan('{glasses}', size: 28, weight: NWFontWeight.bold),
          NWSpan(' / 8 glasses', color: _muted),
        ], style: NWTextStyle(size: 14, monospacedDigits: true)),
      ),
      NWProgress(field: 'glasses', max: 8, color: _water),
      NWRow(
        spacing: 12,
        children: [
          NWButton(
            action: NWAction.increment('glasses', max: 8),
            child: _addGlass,
          ),
          NWButton(
            action: NWAction.set('glasses', '0'),
            child: NWText('Reset', style: NWTextStyle(size: 13, color: _muted)),
          ),
        ],
      ),
    ],
  ),
  background: NWColor('#E0F2FE', dark: '#0C1A26'),
  onTap: NWAction.openApp('/water'),
)
class Water {}

const _addGlass = NWBox(
  padding: NWInsets.symmetric(horizontal: 12, vertical: 5),
  radius: 14,
  color: _water,
  child: NWText(
    '+ Glass',
    style: NWTextStyle(
      size: 13,
      weight: NWFontWeight.semibold,
      color: NWColor.white,
    ),
  ),
);

/// 14. Exchange rate: each copy picks a currency, and its rate in Egyptian
/// pounds is downloaded every hour from a public API, natively.
@HomeScreenWidget(
  displayName: 'Exchange rate',
  description: 'A currency in Egyptian pounds',
  sizes: [NWSize.small],
  fields: [NWField.string('rate', initial: '--')],
  options: [
    NWOption(
      'currency',
      label: 'Currency',
      choices: ['USD', 'EUR', 'SAR', 'GBP'],
    ),
  ],
  refresh: NWRefresh(
    url: 'https://open.er-api.com/v6/latest/{currency}',
    every: Duration(hours: 1),
    values: {'rate': 'rates.EGP'},
  ),
  padding: NWInsets.zero,
  layout: NWBox(
    expand: true,
    padding: NWInsets.all(14),
    alignment: NWAlignment.topStart,
    gradient: NWGradient(
      colors: [
        NWColor('#0F9D58', dark: '#0B5D37'),
        NWColor('#34C38F', dark: '#14532D'),
      ],
    ),
    child: NWColumn(
      crossAxisAlignment: NWCrossAxisAlignment.start,
      mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
      children: [
        NWRow(
          spacing: 4,
          children: [
            NWIcon(
              Icons.currency_exchange,
              size: 14,
              color: NWColor.white,
              sfSymbol: 'dollarsign.arrow.circlepath',
            ),
            NWText(
              '1 {currency}',
              style: NWTextStyle(
                size: 14,
                weight: NWFontWeight.semibold,
                color: NWColor.white,
              ),
            ),
          ],
        ),
        NWColumn(
          crossAxisAlignment: NWCrossAxisAlignment.start,
          children: [
            NWText(
              '{rate}',
              maxLines: 1,
              style: NWTextStyle(
                size: 26,
                weight: NWFontWeight.bold,
                color: NWColor.white,
                monospacedDigits: true,
              ),
            ),
            NWText(
              'Egyptian pounds',
              style: NWTextStyle(size: 12, color: NWColor('#DCFCE7')),
            ),
          ],
        ),
        NWText(
          'Updates every hour',
          style: NWTextStyle(size: 11, color: NWColor('#DCFCE7')),
        ),
      ],
    ),
  ),
)
class ExchangeRate {}

const _tasbeeh = NWColor('#0D9488', dark: '#2DD4BF');

/// 15. Tasbeeh: the number goes up natively on every tap; at 33 a Dart
/// callback moves to the next dhikr.
@HomeScreenWidget(
  displayName: 'تسبيح',
  description: '33 لكل ذكر',
  sizes: [NWSize.small],
  fields: [
    NWField.string('dhikr', initial: 'سبحان الله'),
    NWField.integer('count'),
  ],
  layout: NWColumn(
    mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
    children: [
      NWText(
        '{dhikr}',
        style: NWTextStyle(size: 15, weight: NWFontWeight.semibold),
      ),
      NWButton(
        action: NWAction.increment('count', max: 33),
        child: NWStack(
          children: [
            NWProgress.circular(
              field: 'count',
              max: 33,
              size: 70,
              thickness: 8,
              color: _tasbeeh,
            ),
            NWText(
              '{count}',
              style: NWTextStyle(
                size: 24,
                weight: NWFontWeight.bold,
                monospacedDigits: true,
              ),
            ),
          ],
        ),
      ),
      NWIf(
        condition: NWCondition.greaterThan('count', '32'),
        child: NWButton(
          action: NWAction.callback('next'),
          child: NWBox(
            padding: NWInsets.symmetric(horizontal: 12, vertical: 4),
            radius: 12,
            color: _tasbeeh,
            child: NWText(
              'الذكر التالي ›',
              style: NWTextStyle(size: 12, color: NWColor.white),
            ),
          ),
        ),
        orElse: NWButton(
          action: NWAction.set('count', '0'),
          child: NWText('↺ صفّر', style: NWTextStyle(size: 12, color: _muted)),
        ),
      ),
    ],
  ),
  background: NWColor('#F0FDFA', dark: '#0A1F1D'),
)
class Tasbeeh {}

const _card = NWColor('#7C3AED', dark: '#A78BFA');

/// 16. Flashcards: tap the card to flip it (native toggle); Next runs Dart to
/// pick the next word.
@HomeScreenWidget(
  displayName: 'Flashcards',
  description: 'A new English word',
  sizes: [NWSize.medium],
  fields: [
    NWField.string('word', initial: 'Resilient'),
    NWField.string('meaning', initial: 'مرن، بيقوم بسرعة بعد أي صعوبة'),
    NWField.integer('card', initial: '1'),
    NWField.boolean('revealed'),
  ],
  layout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.stretch,
    mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
    children: [
      NWRow(
        children: [
          NWText(
            'Card {card} / 8',
            style: NWTextStyle(size: 12, color: _muted, monospacedDigits: true),
          ),
          NWSpacer(),
          NWButton(
            action: NWAction.callback('next'),
            child: NWText(
              'Next ›',
              style: NWTextStyle(
                size: 13,
                weight: NWFontWeight.semibold,
                color: _card,
              ),
            ),
          ),
        ],
      ),
      NWButton(
        action: NWAction.toggle('revealed'),
        child: NWColumn(
          spacing: 4,
          children: [
            NWText(
              '{word}',
              style: NWTextStyle(size: 26, weight: NWFontWeight.bold),
            ),
            NWIf(
              condition: NWCondition.isTrue('revealed'),
              child: NWText(
                '{meaning}',
                maxLines: 2,
                align: NWTextAlign.center,
                style: NWTextStyle(size: 15, color: _card),
              ),
              orElse: NWText(
                'Tap to see the meaning',
                style: NWTextStyle(size: 13, color: _muted),
              ),
            ),
          ],
        ),
      ),
      NWSpacer(),
    ],
  ),
  background: NWColor('#F5F3FF', dark: '#1A1530'),
)
class Flashcards {}

const _on = NWColor('#F59E0B', dark: '#FBBF24');
const _off = NWColor('#E5E7EB', dark: '#2C2C2E');

/// 17. Smart home: each tap runs Dart in the background, which flips the
/// device, redraws the widget and sends the change to a server.
@HomeScreenWidget(
  displayName: 'Smart home',
  description: 'Lights, AC and the door',
  sizes: [NWSize.medium],
  fields: [
    NWField.boolean('light'),
    NWField.boolean('ac'),
    NWField.boolean('locked', initial: 'true'),
    NWField.string('status', initial: 'Tap a device'),
  ],
  layout: NWColumn(
    crossAxisAlignment: NWCrossAxisAlignment.stretch,
    mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
    children: [
      NWRow(
        spacing: 6,
        children: [
          NWIcon(Icons.home, size: 16, color: _on),
          NWText(
            'Home',
            style: NWTextStyle(size: 14, weight: NWFontWeight.semibold),
          ),
          NWSpacer(),
          NWText(
            '{status}',
            maxLines: 1,
            style: NWTextStyle(size: 11, color: _muted),
          ),
        ],
      ),
      NWRow(
        mainAxisAlignment: NWMainAxisAlignment.spaceBetween,
        children: [
          NWButton(
            action: NWAction.callback('toggle', payload: 'light'),
            child: NWIf(
              condition: NWCondition.isTrue('light'),
              child: _lightOn,
              orElse: _lightOff,
            ),
          ),
          NWButton(
            action: NWAction.callback('toggle', payload: 'ac'),
            child: NWIf(
              condition: NWCondition.isTrue('ac'),
              child: _acOn,
              orElse: _acOff,
            ),
          ),
          NWButton(
            action: NWAction.callback('toggle', payload: 'locked'),
            child: NWIf(
              condition: NWCondition.isTrue('locked'),
              child: _doorLocked,
              orElse: _doorOpen,
            ),
          ),
        ],
      ),
    ],
  ),
  onTap: NWAction.openApp('/home'),
)
class SmartHome {}

/// Runs in the background when ⏮ or ⏭ is tapped on the Now Playing widget.
@WidgetCallback(widget: 'NowPlaying')
Future<void> onMusicButton(WidgetEvent event) async {
  const tracks = [
    ('Bohemian Rhapsody', 'Queen'),
    ('Ya Msafer Wahdak', 'Mohamed Abdel Wahab'),
    ('Clair de Lune', 'Debussy'),
  ];
  final current = await NowPlayingWidget.read();
  var index = tracks.indexWhere((t) => t.$1 == current.title);
  index = event.name == 'next'
      ? (index + 1) % tracks.length
      : (index - 1 + tracks.length) % tracks.length;
  debugPrint('NowPlaying ${event.name} → ${tracks[index].$1}');
  await NowPlayingWidget.save(
    title: tracks[index].$1,
    artist: tracks[index].$2,
    playing: true,
  );
}

// Each tile has an on and an off look; NWIf picks one.
const _lightOn = NWBox(
  width: 76,
  height: 60,
  radius: 16,
  color: _on,
  child: NWColumn(
    spacing: 4,
    children: [
      NWIcon(
        Icons.lightbulb,
        size: 22,
        color: NWColor.white,
        sfSymbol: 'lightbulb.fill',
      ),
      NWText('Light', style: NWTextStyle(size: 12, color: NWColor.white)),
    ],
  ),
);

const _lightOff = NWBox(
  width: 76,
  height: 60,
  radius: 16,
  color: _off,
  child: NWColumn(
    spacing: 4,
    children: [
      NWIcon(Icons.lightbulb, size: 22, color: _muted, sfSymbol: 'lightbulb'),
      NWText('Light', style: NWTextStyle(size: 12, color: _muted)),
    ],
  ),
);

const _acOn = NWBox(
  width: 76,
  height: 60,
  radius: 16,
  color: _on,
  child: NWColumn(
    spacing: 4,
    children: [
      NWIcon(
        Icons.ac_unit,
        size: 22,
        color: NWColor.white,
        sfSymbol: 'snowflake',
      ),
      NWText('AC', style: NWTextStyle(size: 12, color: NWColor.white)),
    ],
  ),
);

const _acOff = NWBox(
  width: 76,
  height: 60,
  radius: 16,
  color: _off,
  child: NWColumn(
    spacing: 4,
    children: [
      NWIcon(Icons.ac_unit, size: 22, color: _muted, sfSymbol: 'snowflake'),
      NWText('AC', style: NWTextStyle(size: 12, color: _muted)),
    ],
  ),
);

const _doorLocked = NWBox(
  width: 76,
  height: 60,
  radius: 16,
  color: _on,
  child: NWColumn(
    spacing: 4,
    children: [
      NWIcon(Icons.lock, size: 22, color: NWColor.white),
      NWText('Locked', style: NWTextStyle(size: 12, color: NWColor.white)),
    ],
  ),
);

const _doorOpen = NWBox(
  width: 76,
  height: 60,
  radius: 16,
  color: _off,
  child: NWColumn(
    spacing: 4,
    children: [
      NWIcon(Icons.lock_open, size: 22, color: _muted),
      NWText('Open', style: NWTextStyle(size: 12, color: _muted)),
    ],
  ),
);

/// Runs when "الذكر التالي" is tapped on the Tasbeeh widget (after 33).
@WidgetCallback(widget: 'Tasbeeh')
Future<void> onTasbeehNext(WidgetEvent event) async {
  const adhkar = ['سبحان الله', 'الحمد لله', 'الله أكبر'];
  final current = await TasbeehWidget.read();
  final index = adhkar.indexOf(current.dhikr ?? adhkar.first);
  await TasbeehWidget.save(
    dhikr: adhkar[(index + 1) % adhkar.length],
    count: 0,
  );
}

/// Runs when Next is tapped on the Flashcards widget.
@WidgetCallback(widget: 'Flashcards')
Future<void> onNextCard(WidgetEvent event) async {
  const cards = [
    ('Resilient', 'مرن، بيقوم بسرعة بعد أي صعوبة'),
    ('Curious', 'فضولي، بيحب يعرف'),
    ('Generous', 'كريم'),
    ('Reliable', 'يُعتمد عليه'),
    ('Brief', 'مختصر'),
    ('Accurate', 'دقيق'),
    ('Eager', 'متحمّس'),
    ('Humble', 'متواضع'),
  ];
  final current = await FlashcardsWidget.read();
  final next = (current.card ?? 1) % cards.length; // 0-based index of the next
  await FlashcardsWidget.save(
    word: cards[next].$1,
    meaning: cards[next].$2,
    card: next + 1,
    revealed: false,
  );
}

/// Runs when a device is tapped on the Smart home widget. It redraws the
/// widget first, then tells a server (here an echo service) about it.
@WidgetCallback(widget: 'SmartHome')
Future<void> onSmartHomeTap(WidgetEvent event) async {
  final device = event.payload!;
  final current = await SmartHomeWidget.read();
  final on =
      !(switch (device) {
            'light' => current.light,
            'ac' => current.ac,
            _ => current.locked,
          } ??
          false);
  await SmartHomeWidget.save(
    light: device == 'light' ? on : null,
    ac: device == 'ac' ? on : null,
    locked: device == 'locked' ? on : null,
    status: 'Sending…',
  );
  String status;
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final request = await client.postUrl(
      Uri.parse('https://httpbin.org/anything/home'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'device': device, 'on': on}));
    final response = await request.close().timeout(const Duration(seconds: 8));
    client.close();
    status = response.statusCode == 200 ? 'Saved ✓' : 'Server error';
  } catch (e) {
    debugPrint('SmartHome request failed: $e');
    status = 'Offline';
  }
  debugPrint('SmartHome $device → $on: $status');
  await SmartHomeWidget.save(status: status);
}
