// What each example shows, how its data flows, and the app-side code.
// The widget declarations themselves come from examples-code.js.
window.EXAMPLES = [
  {
    id: 'Clock', img: 'clock', size: 'small · medium · Lock Screen',
    title: { ar: 'ساعة', en: 'Clock' },
    summary: {
      ar: 'ساعة وتاريخ النظام بيحدّثهم لوحده والأبليكيشن مقفول. على iOS بتظهر كمان على الـ Lock Screen: ساعة analog في المقاس الدايري، والتاريخ في السطر اللي فوق الساعة.',
      en: 'Time and date the system keeps current while the app is closed. On iOS it also goes on the Lock Screen: an analog clock in the circular size, the date in the inline slot.',
    },
    shows: ['NWClock', 'NWDateText', 'NWAnalogClock', 'circularLayout', 'inlineLayout'],
    flow: {
      ar: ['مفيش داتا خالص: الـ widget دي مالهاش حقول.', 'على أندرويد <code>NWClock</code> بيتحول لـ <code>TextClock</code>، وده بيتحدّث لوحده كل دقيقة.', 'على iOS الـ provider بيعمل timeline فيها entry لكل دقيقة.'],
      en: ['No data at all: this widget has no fields.', 'On Android <code>NWClock</code> becomes a <code>TextClock</code>, which updates itself every minute.', 'On iOS the provider builds a timeline with one entry per minute.'],
    },
    app: null,
  },
  {
    id: 'WatchFace', img: 'watch_face', size: 'medium',
    title: { ar: 'Watch face', en: 'Watch face' },
    summary: {
      ar: 'ساعة analog وجنبها ساعة digital على خلفية gradient، والألوان بتتغير مع الـ dark mode. عقرب الثواني بيتحرك على Android 12+.',
      en: 'An analog and a digital clock on a gradient, with dark-mode colors. The second hand ticks on Android 12+.',
    },
    shows: ['NWAnalogClock', 'NWGradient', 'NWBox', 'NWColor(dark:)', 'padding: NWInsets.zero'],
    flow: {
      ar: ['مالهاش حقول. كل الألوان مكتوبة في الـ layout، وبيتولّد منها <code>values/</code> و <code>values-night/</code>.', 'الساعة الـ analog على أندرويد عبارة عن <code>AnalogClock</code> بعقارب vector بتتولّد حسب الألوان اللي اخترتها.'],
      en: ['No fields. Colors live in the layout and are generated into <code>values/</code> and <code>values-night/</code>.', 'On Android the analog clock is an <code>AnalogClock</code> with vector hands generated from your colors.'],
    },
    app: null,
  },
  {
    id: 'Counter', img: 'counter', size: 'small',
    title: { ar: 'عدّاد', en: 'Counter' },
    summary: {
      ar: 'زراير + و − بتغيّر الرقم على الشاشة الرئيسية من غير ما الأبليكيشن يفتح. ولو دوست على الـ widget نفسها بتفتح الأبليكيشن على <code>/counter</code>.',
      en: 'The + and − buttons change the number on the home screen without opening the app. Tapping the widget itself opens <code>/counter</code>.',
    },
    shows: ['NWField.integer', 'NWAction.increment', 'NWAction.decrement', 'min / max', 'onTap: openApp'],
    flow: {
      ar: ['الأبليكيشن بيكتب: <code>CounterWidget.save(count: …)</code>.', 'الضغطة على +: الـ provider بيقرا <code>fnw.Counter.count</code> ويزوّده (لحد 99)، وبعدين يرسم من غير Dart.', 'الأبليكيشن بيقرا القيمة الجديدة بـ <code>read()</code> لما يرجع للـ foreground.'],
      en: ['The app writes: <code>CounterWidget.save(count: …)</code>.', 'Tapping +: the provider reads <code>fnw.Counter.count</code>, adds one (up to 99) and redraws, with no Dart.', 'The app reads the new value with <code>read()</code> when it comes back to the foreground.'],
    },
    app: `// +10 from the app
await CounterWidget.save(count: _count + 10);

// Read what the widget's buttons did meanwhile
final data = await CounterWidget.read();
setState(() => _count = data.count ?? 0);

// Reset
await CounterWidget.clear();`,
  },
  {
    id: 'Tasks', img: 'tasks', size: 'medium · large',
    title: { ar: 'مهام', en: 'Tasks' },
    summary: {
      ar: 'قايمة فيها لحد 4 مهام. لما تدوس على أي مهمة بتتعلّم ✓ وانت على الشاشة الرئيسية، والصفوف الفاضية مابتظهرش.',
      en: 'A list of up to four tasks. Tapping one ticks it on the home screen; empty rows are hidden.',
    },
    shows: ['NWRepeat', 'repeat: 4', 'title#', 'NWIf', 'NWCondition.notEmpty', 'NWAction.toggle'],
    flow: {
      ar: ['<code>repeat: 4</code> بيعمل 4 مفاتيح: <code>title0..title3</code> و <code>done0..done3</code>، وفي Dart بيبقوا <code>List</code>.', 'جوه <code>NWRepeat</code> علامة <code>#</code> بتتبدّل برقم الصف.', 'الضغطة بتعمل <code>toggle</code> للـ <code>done#</code> الخاص بالصف ده بس، native.'],
      en: ['<code>repeat: 4</code> creates four keys each: <code>title0..title3</code>, <code>done0..done3</code>, exposed as <code>List</code>s in Dart.', 'Inside <code>NWRepeat</code>, <code>#</code> becomes the row index.', 'A tap toggles only that row\'s <code>done#</code>, natively.'],
    },
    app: `await TasksWidget.save(
  title: ['Buy bread', 'Call mom', 'Finish the widget package'],
  done: [false, true, false],
);`,
  },
  {
    id: 'PrayerTimes', img: 'prayer_times', size: 'small · medium · Lock Screen',
    title: { ar: 'مواقيت الصلاة', en: 'Prayer times' },
    summary: {
      ar: 'بتعرض الصلاة الجاية وعدّاد تنازلي ليها. الأبليكيشن بيحفظ اليوم كله مرة واحدة كـ timeline، والـ widget بتنقل للصلاة اللي بعدها لوحدها.',
      en: 'Shows the next prayer and a countdown to it. The app saves the whole day once as a timeline; the widget moves to the next prayer by itself.',
    },
    shows: ['saveTimeline', 'NWTimer', 'NWField.dateTime', 'rectangularLayout', 'RTL'],
    flow: {
      ar: ['<code>save()</code> بيكتب الصلاة الجاية دلوقتي.', '<code>saveTimeline()</code> بيكتب لكل ميعاد صلاة القيم اللي هتظهر من الميعاد ده: الصلاة اللي بعدها والميعاد بتاعها.', 'أندرويد: <code>AlarmManager</code> بيصحّي الـ provider في كل ميعاد. iOS: entries في timeline بتاعة WidgetKit.', '<code>NWTimer</code> بيعد تنازلي لحد <code>nextAt</code> كل ثانية، والنظام هو اللي بيعدّه.'],
      en: ['<code>save()</code> writes the next prayer now.', '<code>saveTimeline()</code> writes, for each prayer time, what to show from then on: the following prayer and its time.', 'Android: <code>AlarmManager</code> wakes the provider at each time. iOS: WidgetKit timeline entries.', '<code>NWTimer</code> counts down to <code>nextAt</code> every second, counted by the system.'],
    },
    app: `await PrayerTimesWidget.save(next: upcoming.first.$1, nextAt: upcoming.first.$2);
await PrayerTimesWidget.saveTimeline([
  for (var i = 0; i < upcoming.length - 1; i++)
    PrayerTimesTimelineEntry(
      upcoming[i].$2,               // at this time…
      next: upcoming[i + 1].$1,     // …show the prayer after it
      nextAt: upcoming[i + 1].$2,
    ),
]);`,
  },
  {
    id: 'Countdown', img: 'countdown', size: 'small',
    title: { ar: 'عدّاد تنازلي', en: 'Countdown' },
    summary: {
      ar: 'بيعد الوقت الفاضل لحد ميعاد معيّن، ولما الوقت يخلص بيقلب لـ "It\'s time!" عن طريق entry واحدة في الـ timeline.',
      en: 'Counts down to an event, then flips to "It\'s time!" through a single timeline entry.',
    },
    shows: ['NWTimer', 'NWIf', 'NWCondition.isTrue', 'saveTimeline'],
    flow: {
      ar: ['الأبليكيشن بيحفظ الحدث والميعاد و <code>finished: false</code>.', 'entry واحدة في الـ timeline في نفس الميعاد بتخلّي <code>finished: true</code>.', '<code>NWIf</code> بيبدّل بين العدّاد والرسالة.'],
      en: ['The app saves the event, its time and <code>finished: false</code>.', 'One timeline entry at that time sets <code>finished: true</code>.', '<code>NWIf</code> switches between the timer and the message.'],
    },
    app: `final at = DateTime.now().add(const Duration(days: 3, hours: 4));
await CountdownWidget.save(event: 'Trip to Alexandria', at: at, finished: false);
await CountdownWidget.saveTimeline([
  CountdownTimelineEntry(at, finished: true),
]);`,
  },
  {
    id: 'NowPlaying', img: 'now_playing', size: 'medium',
    title: { ar: 'مشغّل موسيقى', en: 'Now Playing' },
    summary: {
      ar: 'غلاف الألبوم مرسوم بـ Flutter. زرار play/pause بيشتغل native، و ⏮ و ⏭ بيشغّلوا كود Dart في الـ background علشان يختاروا الأغنية.',
      en: 'The album cover is drawn by Flutter. Play/pause is native; ⏮ and ⏭ run Dart in the background to pick the track.',
    },
    shows: ['NWField.image', 'renderCover', 'NWAction.toggle', 'NWAction.callback', '@WidgetCallback'],
    flow: {
      ar: ['<code>renderCover(...)</code> بيرسم Flutter widget ويحفظها PNG، ويحط المسار في <code>cover</code>.', '▶️/⏸ بيعمل <code>toggle</code> للحقل <code>playing</code>، native.', '⏮/⏭ بيبعتوا <code>WidgetEvent</code> لـ <code>onMusicButton</code> في background isolate، وهو بيقرا الأغنية الحالية ويحفظ اللي بعدها.'],
      en: ['<code>renderCover(...)</code> draws a Flutter widget to a PNG and stores its path in <code>cover</code>.', '▶️/⏸ toggles <code>playing</code> natively.', '⏮/⏭ send a <code>WidgetEvent</code> to <code>onMusicButton</code> in a background isolate, which reads the current track and saves the next.'],
    },
    app: `await NowPlayingWidget.renderCover(
  const _Cover(color: Colors.deepPurple, label: 'Q'),
  size: const Size(144, 144),
  update: false,
);
await NowPlayingWidget.save(
  title: 'Bohemian Rhapsody',
  artist: 'Queen',
  playing: true,
);`,
  },
  {
    id: 'QuickActions', img: 'quick_actions', size: 'medium',
    title: { ar: 'اختصارات', en: 'Quick actions' },
    summary: {
      ar: '4 deep links في widget واحدة، وكل زرار بيفتح route مختلف في الأبليكيشن. الـ tiles معمولة كـ <code>const</code> top-level علشان نستخدمها أكتر من مرة.',
      en: 'Four deep links in one widget; each button opens a different route. Tiles are top-level <code>const</code>s for reuse.',
    },
    shows: ['NWAction.openApp', 'const tiles', 'spaceBetween', 'FlutterNativeWidget.launches'],
    flow: {
      ar: ['الضغطة بتفتح الأبليكيشن بـ URI فيه الـ route.', 'الأبليكيشن بيستلمه من <code>launches</code> أو <code>initialLaunch()</code>.'],
      en: ['A tap opens the app with a URI carrying the route.', 'The app receives it from <code>launches</code> or <code>initialLaunch()</code>.'],
    },
    app: `FlutterNativeWidget.initialLaunch().then((launch) {
  if (launch != null) _onLaunch(launch);
});
_launches = FlutterNativeWidget.launches.listen(_onLaunch);

void _onLaunch(WidgetLaunch launch) {
  // launch.widget == 'QuickActions', launch.route == '/tasks'
  Navigator.of(context).pushNamed(launch.route ?? '/');
}`,
  },
  {
    id: 'Steps', img: 'steps', size: 'medium',
    title: { ar: 'خطوات الأسبوع', en: 'Steps' },
    summary: {
      ar: 'Chart مرسوم بـ Flutter (أعمدة عادية) ومحطوط في الـ widget كصورة، وفوقه نصوص native. ده الحل لأي حاجة الـ DSL مايقدرش يرسمها.',
      en: 'A chart drawn by Flutter (plain bars) shown as an image, with native text on top. The way out for anything the DSL can\'t draw.',
    },
    shows: ['NWField.image', 'render<Field>', 'NWImageFit.contain', 'NWSpacer'],
    flow: {
      ar: ['<code>renderChart(widget, size:)</code> بيرسم الـ widget بالمقاس المظبوط ويحفظها PNG.', 'الصورة ثابتة لحد ما ترسمها تاني. ممكن تعيد رسمها من الأبليكيشن أو من callback.'],
      en: ['<code>renderChart(widget, size:)</code> lays the widget out at that exact size and saves a PNG.', 'The image stays until you render it again, from the app or a callback.'],
    },
    app: `final steps = [for (var i = 0; i < 7; i++) 3000 + random.nextInt(9000)];
await StepsWidget.renderChart(
  _StepsChart(steps: steps),       // any Flutter widget
  size: const Size(320, 110),
  update: false,
);
await StepsWidget.save(total: steps.reduce((a, b) => a + b).toString());`,
  },
  {
    id: 'PhotoAlbum', img: 'photo_album', size: 'small · large',
    title: { ar: 'ألبوم صور', en: 'Photo album' },
    summary: {
      ar: 'الأبليكيشن بيرسم الصور مرة واحدة ويحفظها كـ timeline، والـ widget بتعرض صورة جديدة كل ساعة لوحدها.',
      en: 'The app renders the photos once and saves them as a timeline; the widget shows the next one every hour by itself.',
    },
    shows: ['NWStack', 'NWImage', 'renderImage', 'saveTimeline', 'NWAlignment.bottomStart'],
    flow: {
      ar: ['<code>FlutterNativeWidget.renderImage</code> بيرسم كل صورة في ملف لوحدها (<code>photo0</code> و <code>photo1</code>…).', 'الصورة الأولى بتتحفظ دلوقتي، والباقي في timeline، entry لكل ساعة.', 'الـ widget بتبدّل المسار في المواعيد دي والأبليكيشن مقفول.'],
      en: ['<code>FlutterNativeWidget.renderImage</code> renders each photo to its own file (<code>photo0</code>, <code>photo1</code>…).', 'The first is saved now, the rest in a timeline, one entry per hour.', 'The widget swaps the path at those times with the app closed.'],
    },
    app: `final paths = [
  for (final (i, (_, emoji, color)) in photos.indexed)
    await FlutterNativeWidget.renderImage(
      _Photo(emoji: emoji, color: color),
      widget: PhotoAlbumWidget.name,
      field: 'photo$i',
      logicalSize: const Size(360, 360),
    ),
];
await PhotoAlbumWidget.save(photo: paths.first, caption: photos.first.$1, update: false);
await PhotoAlbumWidget.saveTimeline([
  for (var i = 1; i < photos.length; i++)
    PhotoAlbumTimelineEntry(start.add(every * i), photo: paths[i], caption: photos[i].$1),
]);`,
  },
  {
    id: 'Activity', img: 'activity', size: 'small',
    title: { ar: 'النشاط', en: 'Activity' },
    summary: {
      ar: 'حلقتين progress جوه بعض زي Apple Fitness، وأيقونات النظام، و rich text، وخط مخصص من ملف <code>.ttf</code>.',
      en: 'Two nested progress rings like Apple Fitness, system icons, rich text and a custom <code>.ttf</code> font.',
    },
    shows: ['NWProgress.circular', 'NWStack', 'NWIcon(Icons.x)', 'NWRichText', 'NWSpan', 'font:'],
    flow: {
      ar: ['<code>move</code> و <code>exercise</code> أرقام عشرية من 0 لـ 1، وكل واحد بيملا حلقة.', 'على أندرويد الأيقونة بتتحول لـ vector drawable صغير، وعلى iOS لـ SF Symbol.', 'الخط بيتنسخ لـ <code>res/font</code> وللـ extension على iOS.'],
      en: ['<code>move</code> and <code>exercise</code> are decimals from 0 to 1, each filling a ring.', 'The icon becomes a small vector drawable on Android and an SF Symbol on iOS.', 'The font is copied to <code>res/font</code> and into the iOS extension.'],
    },
    app: `ActivityWidget.save(
  steps: 2000 + random.nextInt(9000),
  move: random.nextDouble(),
  exercise: random.nextDouble(),
);`,
  },
  {
    id: 'News', img: 'news', size: 'medium · large',
    title: { ar: 'أخبار', en: 'News' },
    summary: {
      ar: 'قايمة بتعمل scroll على Android 12+، وبتحمّل عناوين الأخبار من النت كل 30 دقيقة والأبليكيشن مقفول. لما تدوس على خبر بيتعلّم إنه اتقرا.',
      en: 'A list that scrolls on Android 12+ and downloads its headlines every 30 minutes with the app closed. Tapping one marks it read.',
    },
    shows: ['NWList', 'NWRefresh', "'title#': 'posts.#.title'", 'NWIcon', 'NWAction.toggle'],
    flow: {
      ar: ['<code>NWRefresh</code> بيحمّل <code>dummyjson.com/posts</code> بكود native.', '<code>posts.#.title</code> بيملا <code>title0..title9</code>.', 'على أندرويد <code>NWList</code> بتبقى <code>ListView</code> بـ <code>RemoteViews</code> collection. على iOS بيظهر اللي يكفي من العناصر بس.', 'الأبليكيشن يقدر كمان يحفظ العناوين بنفسه.'],
      en: ['<code>NWRefresh</code> downloads <code>dummyjson.com/posts</code> natively.', '<code>posts.#.title</code> fills <code>title0..title9</code>.', 'On Android <code>NWList</code> becomes a <code>ListView</code> backed by a <code>RemoteViews</code> collection; iOS shows the items that fit.', 'The app can also save headlines itself.'],
    },
    app: `await NewsWidget.save(
  title: [for (var i = 1; i <= 10; i++) 'Sample headline $i'],
);`,
  },
  {
    id: 'Weather', img: 'weather', size: 'small',
    title: { ar: 'الطقس', en: 'Weather' },
    summary: {
      ar: 'كل نسخة من الـ widget بتعرض المدينة اللي المستخدم اختارها، والطقس بيتحمّل لكل مدينة لوحده بكود native كل 30 دقيقة.',
      en: 'Each copy shows the city the user picked; the weather for it is downloaded natively every 30 minutes.',
    },
    shows: ['NWOption', 'NWRefresh', '{city} in URL', 'saveForCity', 'NWGradient'],
    flow: {
      ar: ['المستخدم بيختار المدينة: على أندرويد لما يضيف الـ widget، وعلى iOS 17+ من Edit widget.', '<code>{city}</code> في الـ URL بتتبدّل، فكل اختيار بيتحمّل لوحده.', 'الأبليكيشن يقدر يحفظ قيم لكل مدينة بـ <code>saveForCity</code>.'],
      en: ['The user picks a city: when placing it on Android, from Edit widget on iOS 17+.', '<code>{city}</code> in the URL is filled in, so each choice is downloaded on its own.', 'The app can save values per city with <code>saveForCity</code>.'],
    },
    app: `for (final city in WeatherWidget.cityChoices) {
  await WeatherWidget.saveForCity(
    city,
    temp: '\${city.length + 15}',
    sky: 'Saved by the app',
    update: false,
  );
}
await WeatherWidget.update();`,
  },
  {
    id: 'Water', img: 'water', size: 'small · medium', isNew: true,
    title: { ar: 'شرب المية', en: 'Water' },
    summary: {
      ar: 'بتعدّ كوبايات المية. في المقاس الصغير بتظهر حلقة، وفي المتوسط bar. فيها زرار + Glass، وزرار Reset، وزرار بيغيّر مقاس الكوباية، وكلهم بيشتغلوا من غير ما الأبليكيشن يفتح.',
      en: 'Counts glasses of water: a ring on small, a bar on medium. + Glass, Reset and the cup size all work without opening the app.',
    },
    shows: ['smallLayout', 'NWProgress', 'NWProgress.circular', 'NWAction.set', 'NWAction.cycle', 'NWCondition.greaterThan'],
    flow: {
      ar: ['<code>increment(max: 8)</code> بيزوّد <code>glasses</code>، native.', '<code>set(\'glasses\', \'0\')</code> بيصفّر العدد.', '<code>cycle</code> بيلف <code>cup</code> على 250 و 330 و 500 ml.', '<code>greaterThan(\'glasses\', \'7\')</code> بيقارن كأرقام، فلما توصل 8 تظهر رسالة "Goal reached 🎉".'],
      en: ['<code>increment(max: 8)</code> adds to <code>glasses</code> natively.', '<code>set(\'glasses\', \'0\')</code> resets it.', '<code>cycle</code> rotates <code>cup</code> through 250, 330 and 500 ml.', '<code>greaterThan(\'glasses\', \'7\')</code> compares numerically; at 8 it shows "Goal reached 🎉".'],
    },
    app: `await WaterWidget.save(glasses: 5);   // "Set 5 glasses"
await WaterWidget.clear();             // "New day"`,
  },
];
