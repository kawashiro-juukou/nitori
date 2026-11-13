import 'package:nitori_message/nitori_message.dart' as n;
import 'package:test/test.dart';

/// Spells the HTML entity text the parser tests need, built from code points
/// so the exact entity strings survive editing of this file.
String ent(String spec) {
  final amp = String.fromCharCode(0x26);
  final lt = String.fromCharCodes(const [0x26, 0x6c, 0x74, 0x3b]);
  final gt = String.fromCharCodes(const [0x26, 0x67, 0x74, 0x3b]);
  final quot = String.fromCharCodes(const [0x26, 0x71, 0x75, 0x6f, 0x74, 0x3b]);
  final hash = String.fromCharCodes(const [0x26, 0x23]);
  final out = StringBuffer();
  for (var i = 0; i < spec.length; i++) {
    out.writeCharCode(spec.codeUnitAt(i));
  }
  var text = out.toString();
  text = text.replaceAll('AMP', amp);
  text = text.replaceAll('LT', lt);
  text = text.replaceAll('GT', gt);
  text = text.replaceAll('QUOT', quot);
  text = text.replaceAll('HASH', hash);
  return text;
}

void main() {
  group('Base', () {
    test('BaseElement', () {
      expect(n.Base('test').toString(), equals('<test/>'));
      expect(
        n.Base('test', attributes: {'id': '001'}).toString(),
        equals('<test id="001"/>'),
      );
      expect(
        n.Base('test', attributes: {'id': '001', 'name': 'test'}).toString(),
        equals('<test id="001" name="test"/>'),
      );
    });

    test('Escape', () {
      expect(n.escape('<test/>'), equals('&lt;test/&gt;'));
      expect(n.escape('"test"'), equals('&quot;test&quot;'));
      expect(n.escape('&test&'), equals('&amp;test&amp;'));
    });

    test('Unescape', () {
      expect(n.unescape('&lt;test/&gt;'), equals('<test/>'));
      expect(n.unescape('&quot;test&quot;'), equals('"test"'));
      expect(n.unescape('&amp;test&amp;'), equals('&test&'));
    });

    test('Unescape keeps escaped entities as literal text', () {
      final lt = String.fromCharCode(0x3C);
      final lt2 = String.fromCharCode(0x3C);
      final amp = String.fromCharCode(0x26);
      final quot = String.fromCharCode(0x22);
      // `&` is decoded last, so an escaped `<` stays literal text.
      expect(n.unescape(ent('LTLT')), equals(lt + lt));
      expect(n.unescape(ent('AMPLTLT')), equals(amp + lt + lt2));
      expect(n.unescape(ent('AMPAMPAMP')), equals(amp + amp + amp));
      expect(n.unescape(ent('AMPQUOTQUOT')), equals(amp + quot + quot));
    });

    test('Unescape resolves numeric entities', () {
      final num = String.fromCharCodes(const [0x26, 0x23]);
      final hex = String.fromCharCodes(const [0x26, 0x23, 0x78]);
      final quote = String.fromCharCode(0x27);
      expect(
        n.unescape(
          '$num'
          '39;',
        ),
        equals(quote),
      );
      expect(
        n.unescape(
          '$hex'
          '27;',
        ),
        equals(quote),
      );
      expect(
        n.unescape(
          '$num'
          '65;',
        ),
        equals('A'),
      );
      expect(
        n.unescape(
          '$hex'
          '26;',
        ),
        equals('&'),
      );
      expect(
        n.unescape(
          '$num'
          '38;',
        ),
        equals('&'),
      );
      expect(
        n.unescape(
          'a$num'
          '38;b',
        ),
        equals('a&b'),
      );
    });

    test('Boolean attribute serialization', () {
      expect(
        n.Base('test', attributes: {'flag': true}).toString(),
        equals('<test flag/>'),
      );
      expect(
        n.Base('test', attributes: {'flag': false}).toString(),
        equals('<test no-flag/>'),
      );
    });
  });
}
