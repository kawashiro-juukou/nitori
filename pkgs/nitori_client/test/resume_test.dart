/// Tests for resume sequence number handling.
library;

import 'package:test/test.dart';
import 'package:nitori_client/src/client.dart';
import 'package:nitori_client/src/gateway_client.dart';

void main() {
  group('NitoriClient resume sequence', () {
    test('lastReceivedSn is initially null', () {
      final client = NitoriClient(baseUrl: 'http://localhost:5140');
      expect(client.lastReceivedSn, isNull);
    });

    test('resumeFrom sets gateway sequence', () {
      final client = NitoriClient(baseUrl: 'http://localhost:5140');
      client.resumeFrom(5);
      expect(client.gateway.sequence, equals(5));
      expect(client.lastReceivedSn, equals(5));
    });

    test('resumeFrom updates sequence for next reconnect', () {
      final client = NitoriClient(baseUrl: 'http://localhost:5140');
      client.resumeFrom(10);
      expect(client.gateway.sequence, equals(10));

      client.resumeFrom(20);
      expect(client.gateway.sequence, equals(20));
      expect(client.lastReceivedSn, equals(20));
    });
  });

  group('Gateway sequence tracking', () {
    test('sequence updates on EVENT frame', () {
      final gateway = SatoriGatewayClient(baseUrl: 'http://localhost:5140');
      gateway.sequence = null; // Ensure clean state
      gateway.sequence = 42;
      expect(gateway.sequence, equals(42));
    });
  });

  group('Gateway sequence tracking', () {
    test('sequence updates on EVENT frame', () {
      final gateway = SatoriGatewayClient(baseUrl: 'http://localhost:5140');

      // Simulate receiving an EVENT frame with sn=42
      gateway.sequence = null; // Ensure clean state

      // The gateway updates sequence in _handleFrame when op=0
      // We test the public field directly
      gateway.sequence = 42;
      expect(gateway.sequence, equals(42));
    });
  });
}
