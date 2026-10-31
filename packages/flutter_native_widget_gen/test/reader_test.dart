import 'package:flutter_native_widget_gen/src/ir.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('reads a widget with fields, actions and defaults', () async {
    final w = await readWidget('''
@HomeScreenWidget(
  displayName: 'Counter',
  fields: [NWField.integer('count')],
  layout: NWColumn(children: [
    NWText('Count: {count}'),
    NWButton(child: NWText('+'), action: NWAction.increment('count', max: 9)),
  ]),
)
class CounterWidget {}
''');
    expect(w.name, 'Counter', reason: 'the Widget suffix is dropped');
    expect(w.displayName, 'Counter');
    expect(w.sizes, ['small', 'medium']);
    expect(w.initialValues, {'count': '0'});
    expect(w.background, const ColorIR('#FFFFFFFF', '#FF1C1C1E'));
    expect(w.onTap.kind, ActionKind.openApp);

    final column = w.layout;
    expect(column.type, 'column');
    expect(column.children[0].prop<String>('text'), 'Count: {count}');
    final button = column.children[1];
    expect(button.type, 'button');
    expect(button.action.kind, ActionKind.increment);
    expect(button.action.max, 9);
  });

  test('expands NWRepeat and repeated fields', () async {
    final w = await readWidget('''
@HomeScreenWidget(
  fields: [NWField.string('title', repeat: 3), NWField.boolean('done', repeat: 3)],
  layout: NWRepeat(
    count: 3,
    child: NWButton(action: NWAction.toggle('done#'), child: NWText('{title#}')),
  ),
)
class Tasks {}
''');
    expect(w.initialValues.keys, [
      'title0', 'title1', 'title2', 'done0', 'done1', 'done2', //
    ]);
    expect(w.layout.type, 'column');
    expect(w.layout.children, hasLength(3));
    expect(w.layout.children[2].action.key, 'done2');
    expect(
      w.layout.children[2].children.single.prop<String>('text'),
      '{title2}',
    );
  });

  test('reads gradients, borders and analog clocks', () async {
    final w = await readWidget('''
@HomeScreenWidget(
  layout: NWBox(
    gradient: NWGradient(colors: [NWColor('#000000'), NWColor('#FFFFFF')]),
    borderColor: NWColor('#FF0000'),
    child: NWAnalogClock(size: 90, secondHand: NWColor('#FF8800')),
  ),
)
class Face {}
''');
    final gradient = w.layout.props['gradient'] as Map;
    expect((gradient['colors'] as List), hasLength(2));
    expect(w.layout.color('borderColor')!.light, '#FFFF0000');
    final clock = w.layout.children.single;
    expect(clock.type, 'analog');
    expect(clock.number('size'), 90);
    expect(clock.color('second')!.light, '#FFFF8800');
    expect(w.hasClock, isTrue);
  });

  test('reads @WidgetCallback functions', () async {
    final library = await readSource('''
@WidgetCallback(widget: 'Music')
Future<void> onMusic(Object event) async {}
''');
    expect(library.callbacks.single.function, 'onMusic');
    expect(library.callbacks.single.widget, 'Music');
  });

  group('reports mistakes clearly', () {
    test('unknown field in a template', () async {
      expect(
        await errorOf('''
@HomeScreenWidget(layout: NWText('{missing}'))
class A {}
'''),
        allOf(
          contains('`missing`'),
          contains('not a declared field'),
          contains('NWText'),
        ),
      );
    });

    test('wrong field type for an action', () async {
      expect(
        await errorOf('''
@HomeScreenWidget(
  fields: [NWField.string('title')],
  layout: NWButton(child: NWText('x'), action: NWAction.increment('title')),
)
class A {}
'''),
        contains('needs a field of type integer, but `title` is string'),
      );
    });

    test('reserved field names', () async {
      expect(
        await errorOf('''
@HomeScreenWidget(fields: [NWField.string('update')], layout: NWText('x'))
class A {}
'''),
        contains('reserved'),
      );
    });

    test('repeated field used without an index', () async {
      expect(
        await errorOf('''
@HomeScreenWidget(
  fields: [NWField.string('title', repeat: 2)],
  layout: NWText('{title}'),
)
class A {}
'''),
        contains('use `title#` inside NWRepeat'),
      );
    });

    test('size layout for an undeclared size', () async {
      expect(
        await errorOf('''
@HomeScreenWidget(sizes: [NWSize.small], layout: NWText('a'), largeLayout: NWText('b'))
class A {}
'''),
        contains('`largeLayout` is set but `sizes` does not include large'),
      );
    });
  });
}
