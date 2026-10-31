import 'package:flutter_native_widget/src/runtime/protocol.dart';
import 'package:flutter_native_widget/src/runtime/runtime.dart';
import 'package:flutter_test/flutter_test.dart';

// Must match Fnw.applyAction (Kotlin) and FNW.apply (Swift) in the generated code.
void main() {
  String? apply(String uri, String? current, [String initial = '']) =>
      applyAction(Uri.parse(uri), current, initial);

  test('increment and decrement respect bounds', () {
    expect(apply('fnw://action?homeWidget&w=C&op=inc&k=n&by=1', '4'), '5');
    expect(
      apply('fnw://action?homeWidget&w=C&op=inc&k=n&by=1&max=5', '5'),
      '5',
    );
    expect(
      apply('fnw://action?homeWidget&w=C&op=dec&k=n&by=2&min=0', '1'),
      '0',
    );
    expect(
      apply('fnw://action?homeWidget&w=C&op=inc&k=n&by=1', null, '7'),
      '8',
    );
  });

  test('toggle, set and cycle', () {
    expect(apply('fnw://action?homeWidget&w=C&op=toggle&k=b', 'true'), 'false');
    expect(
      apply('fnw://action?homeWidget&w=C&op=toggle&k=b', null, 'false'),
      'true',
    );
    expect(apply('fnw://action?homeWidget&w=C&op=set&k=s&v=a%20b', 'x'), 'a b');
    const cycle =
        'fnw://action?homeWidget&w=C&op=cycle&k=m&vs=%5B%22a%22%2C%22b%22%5D';
    expect(apply(cycle, 'a'), 'b');
    expect(apply(cycle, 'b'), 'a');
    expect(apply(cycle, 'zzz'), 'a');
  });

  test('parses callback and launch URIs', () {
    final event = WidgetEvent.fromUri(
      Uri.parse('fnw://callback?homeWidget&w=Music&n=next&p=42'),
    )!;
    expect([event.widget, event.name, event.payload], ['Music', 'next', '42']);

    final launch = WidgetLaunch.fromUri(
      Uri.parse('fnw://open?homeWidget&w=Tasks&route=%2Ftasks'),
    );
    expect([launch.widget, launch.route], ['Tasks', '/tasks']);
  });

  test('storage keys', () {
    expect(storageKey('Counter', 'count'), 'fnw.Counter.count');
    expect(timelineKey('Counter'), 'fnw.Counter.__timeline');
  });
}
