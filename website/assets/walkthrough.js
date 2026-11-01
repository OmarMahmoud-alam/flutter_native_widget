// A short, video-like walkthrough of the Get started steps. The terminal
// output is what the commands really print on a fresh `flutter create` app;
// the last scene is a screen recording from an Android 15 emulator.
(function () {
  const root = document.getElementById('walkthrough');
  if (!root) return;

  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // kind: 'term' (cmd + output), 'code' (file typed in), 'tree', 'video'.
  const scenes = [
    {
      title: { ar: 'ثبّت الباكدجات', en: 'Install the packages' },
      caption: {
        ar: 'باكدج واحدة في <b>dependencies</b>، والـ generator و build_runner في <b>dev_dependencies</b>.',
        en: 'One package in <b>dependencies</b>; the generator and build_runner in <b>dev_dependencies</b>.',
      },
      kind: 'term', file: 'my_app',
      lines: [
        ['$', 'flutter pub add flutter_native_widget'],
        ['', 'Resolving dependencies...'],
        ['+', '+ flutter_native_widget 0.1.0'],
        ['', 'Changed 25 dependencies!'],
        ['$', 'flutter pub add dev:flutter_native_widget_gen dev:build_runner'],
        ['', 'Resolving dependencies...'],
        ['+', '+ build_runner 2.17.1'],
        ['+', '+ flutter_native_widget_gen 0.1.0'],
        ['', 'Changed 31 dependencies!'],
      ],
    },
    {
      title: { ar: 'جهّز المشروع (مرة واحدة)', en: 'Set up the project (once)' },
      caption: {
        ar: '<code>init</code> بيعمل الـ Widget Extension بتاع iOS ويربطه، ومش هتحتاج تفتح Xcode.',
        en: '<code>init</code> creates and wires up the iOS Widget Extension. No Xcode needed.',
      },
      kind: 'term', file: 'my_app',
      lines: [
        ['$', 'dart run flutter_native_widget_gen init'],
        ['ok', 'Created flutter_native_widget.yaml (App Group: group.com.example.myApp).'],
        ['', '  updated ios/FNWWidgets/Info.plist'],
        ['', '  updated ios/FNWWidgets/FNWWidgets.entitlements'],
        ['', '  updated ios/Runner/Runner.entitlements'],
        ['', '  updated ios/Flutter/FNWWidgets.xcconfig'],
        ['', '  updated ios/Runner.xcodeproj/project.pbxproj'],
        ['', '  updated ios/Runner/AppDelegate.swift'],
        ['', '  wrote   android/app/src/main/AndroidManifest.xml'],
        ['ok', 'Done.'],
      ],
    },
    {
      title: { ar: 'اكتب الـ widget', en: 'Write the widget' },
      caption: {
        ar: 'ملف جديد في <code>lib/</code>. متنساش <code>class Counter {}</code> في الآخر: منها هيطلع <code>CounterWidget</code>.',
        en: 'A new file in <code>lib/</code>. Don\'t forget <code>class Counter {}</code> at the end: it becomes <code>CounterWidget</code>.',
      },
      kind: 'code', file: 'lib/widgets.dart',
      code: `import 'package:flutter_native_widget/flutter_native_widget.dart';

part 'widgets.fnw.dart';

@HomeScreenWidget(
  displayName: 'Counter',
  fields: [NWField.integer('count')],
  layout: NWColumn(children: [
    NWText('{count}', style: NWTextStyle(size: 44)),
    NWRow(spacing: 12, children: [
      NWButton(action: NWAction.decrement('count', min: 0), child: NWText('−')),
      NWButton(action: NWAction.increment('count'), child: NWText('+')),
    ]),
  ]),
)
class Counter {}`,
      mark: ["part 'widgets.fnw.dart';", 'class Counter {}'],
    },
    {
      title: { ar: 'ولّد الكود', en: 'Generate the code' },
      caption: {
        ar: '<code>build_runner</code> بيكتب الـ Dart والـ Kotlin والـ Swift. شغّله تاني كل ما تغيّر الـ widget.',
        en: '<code>build_runner</code> writes the Dart, Kotlin and Swift. Run it again whenever you change the widget.',
      },
      kind: 'term', file: 'my_app',
      lines: [
        ['$', 'dart run build_runner build'],
        ['', '  flutter_native_widget_gen:ir on 2 inputs: 1 output, 1 no-op'],
        ['', '  flutter_native_widget_gen:native on 1 input: 1 output'],
        ['', '  flutter_native_widget_gen:dart on 2 inputs: 1 skipped, 1 output'],
        ['ok', '  Built with build_runner/aot in 13s; wrote 3 outputs.'],
      ],
      tree: [
        ['lib/', ''],
        ['  main.dart', ''],
        ['  widgets.dart', ''],
        ['  widgets.fnw.dart', 'new'],
        ['  home_widgets.g.dart', 'new'],
      ],
    },
    {
      title: { ar: 'سطر في main', en: 'One line in main' },
      caption: {
        ar: 'نادي <code>initializeHomeWidgets()</code> قبل <code>runApp</code>. وبعدها تقدر تستخدم <code>CounterWidget.save(...)</code> في أي حتة.',
        en: 'Call <code>initializeHomeWidgets()</code> before <code>runApp</code>. Then use <code>CounterWidget.save(...)</code> anywhere.',
      },
      kind: 'code', file: 'lib/main.dart',
      code: `import 'package:flutter/material.dart';
import 'home_widgets.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeHomeWidgets();
  runApp(const MyApp());
}

// Anywhere in the app:
await CounterWidget.save(count: 10);`,
      mark: ["import 'home_widgets.g.dart';", 'WidgetsFlutterBinding.ensureInitialized();', 'await initializeHomeWidgets();', 'await CounterWidget.save(count: 10);'],
    },
    {
      title: { ar: 'شغّل وجرّب', en: 'Run and try it' },
      caption: {
        ar: 'تسجيل حقيقي: زراير + و − بتغيّر الرقم، والمهمة بتتعلّم ✓، والأبليكيشن مقفول.',
        en: 'A real recording: + and − change the number and the task gets ticked, with the app closed.',
      },
      kind: 'video', src: 'media/widget-taps.mp4', poster: 'media/widget-taps.jpg', dur: 10500,
    },
  ];

  const lang = () => document.documentElement.dataset.lang || 'en';
  const both = o => `<span lang="ar">${o.ar}</span><span lang="en">${o.en}</span>`;

  root.innerHTML = `
    <div class="wt-stage" aria-live="off">
      <div class="wt-window">
        <div class="wt-bar"><i></i><i></i><i></i><span class="wt-file"></span></div>
        <div class="wt-body"></div>
      </div>
    </div>
    <div class="wt-caption">
      <span class="wt-step"></span>
      <div><b class="wt-title"></b><p class="wt-text"></p></div>
    </div>
    <div class="wt-controls">
      <button type="button" class="wt-play" aria-label="Play / pause"></button>
      <div class="wt-chapters">${scenes.map((s, i) => `
        <button type="button" class="wt-ch" data-i="${i}" aria-label="${s.title.en}">
          <span class="wt-fill"></span><span class="wt-n">${i + 1}</span><span class="wt-name">${both(s.title)}</span>
        </button>`).join('')}
      </div>
    </div>`;

  const body = root.querySelector('.wt-body');
  const fileEl = root.querySelector('.wt-file');
  const chs = [...root.querySelectorAll('.wt-ch')];
  const playBtn = root.querySelector('.wt-play');

  let index = 0, playing = false, token = 0, sceneStart = 0, sceneDur = 1, raf = 0, video = null, pausedAt = 0;

  const sleep = (ms, t) => new Promise(r => setTimeout(() => r(t === token), ms));

  function highlight(code) {
    const el = document.createElement('code');
    el.className = 'language-dart';
    el.textContent = code;
    if (window.Prism) Prism.highlightElement(el);
    return el.innerHTML;
  }

  // Each scene renders itself and returns how long it lasts.
  async function render(i, t) {
    const s = scenes[i];
    fileEl.textContent = s.file || 'Android 15';
    body.className = 'wt-body ' + s.kind;
    root.querySelector('.wt-step').textContent = i + 1;
    root.querySelector('.wt-title').innerHTML = both(s.title);
    root.querySelector('.wt-text').innerHTML = both(s.caption);
    chs.forEach((c, j) => c.classList.toggle('done', j < i));
    chs.forEach((c, j) => c.classList.toggle('on', j === i));

    if (s.kind === 'video') {
      body.innerHTML = `<video muted playsinline preload="auto" poster="${s.poster}" src="${s.src}"></video>`;
      video = body.querySelector('video');
      video.currentTime = 0;
      if (playing) video.play().catch(() => {});
      return s.dur;
    }
    video = null;

    if (s.kind === 'term') {
      body.innerHTML = '<pre class="wt-term"></pre>' + (s.tree ? '<div class="wt-tree"></div>' : '');
      const pre = body.querySelector('pre');
      const fast = reduce || !playing;
      for (const [k, text] of s.lines) {
        const line = document.createElement('div');
        line.className = 'wt-line ' + (k === '$' ? 'cmd' : k === '+' ? 'add' : k === 'ok' ? 'ok' : '');
        pre.appendChild(line);
        if (k === '$') {
          line.innerHTML = '<span class="p">$ </span><span class="t"></span><span class="cur"></span>';
          const tEl = line.querySelector('.t');
          if (fast) tEl.textContent = text;
          else for (let c = 1; c <= text.length; c++) {
            tEl.textContent = text.slice(0, c);
            if (!(await sleep(28, t))) return 0;
          }
          line.querySelector('.cur').remove();
          if (!fast && !(await sleep(350, t))) return 0;
        } else {
          line.textContent = text;
          if (!fast && !(await sleep(170, t))) return 0;
        }
      }
      if (s.tree) {
        const tree = body.querySelector('.wt-tree');
        tree.innerHTML = s.tree.map(([n, tag]) => `<div class="${tag}">${esc(n)}${tag ? ' <em>new</em>' : ''}</div>`).join('');
        setTimeout(() => tree.classList.add('show'), 30);
      }
      return 2600;
    }

    if (s.kind === 'code') {
      body.innerHTML = '<pre class="wt-code"><code class="language-dart"></code></pre>';
      const codeEl = body.querySelector('code');
      const fast = reduce || !playing;
      const lines = s.code.split('\n');
      for (let n = 1; n <= lines.length; n++) {
        codeEl.innerHTML = highlight(lines.slice(0, n).join('\n'));
        if (!fast && !(await sleep(110, t))) return 0;
      }
      // Mark the lines that matter.
      const html = s.code.split('\n').map(l => {
        const h = highlight(l);
        return s.mark.some(m => l.trim() === m) ? `<span class="wt-mark">${h}</span>` : h;
      }).join('\n');
      codeEl.innerHTML = html;
      return 3200;
    }
    return 2000;
  }

  async function go(i) {
    const t = ++token;
    index = i;
    clearTimeout(raf);
    chs.forEach(c => c.style.setProperty('--p', 0));
    const extra = await render(i, t);
    if (t !== token) return;
    if (!playing) return;
    sceneStart = performance.now();
    sceneDur = extra;
    tick(t);
  }

  function tick(t) {
    if (t !== token || !playing) return;
    const p = Math.min(1, (performance.now() - sceneStart) / sceneDur);
    chs[index].style.setProperty('--p', p);
    if (p >= 1) {
      go((index + 1) % scenes.length);
      return;
    }
    raf = setTimeout(() => tick(t), 50);
  }

  function setPlaying(p) {
    playing = p;
    root.classList.toggle('playing', p);
    playBtn.innerHTML = p ? '❚❚' : '▶';
    if (p) {
      if (video) video.play().catch(() => {});
      go(index);
    } else {
      token++;
      clearTimeout(raf);
      if (video) video.pause();
      render(index, token); // show the finished scene
    }
  }

  playBtn.addEventListener('click', () => setPlaying(!playing));
  chs.forEach(c => c.addEventListener('click', () => {
    index = +c.dataset.i;
    if (playing) go(index); else render(index, ++token);
  }));

  // Start when it scrolls into view (once), unless the visitor prefers less motion.
  render(0, ++token);
  playBtn.innerHTML = '▶';
  if (!reduce && 'IntersectionObserver' in window) {
    let started = false;
    new IntersectionObserver(entries => {
      if (entries[0].isIntersecting && !started) { started = true; setPlaying(true); }
    }, { threshold: 0.5 }).observe(root);
  }
})();
