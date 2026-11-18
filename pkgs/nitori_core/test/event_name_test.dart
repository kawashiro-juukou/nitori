import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

void main() {
  test('EventName.from resolves interaction/button', () {
    expect(EventName.from('interaction/button'), EventName.interactionButton);
  });
}
