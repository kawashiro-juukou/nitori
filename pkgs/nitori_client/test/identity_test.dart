/// Identity headers tests for [Gateway] and [NitoriClient].
library;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:nitori_client/nitori_client.dart';

/// Minimal mock HTTP client for tests.
class _MockHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream.value(const <int>[]), 200);
  }
}

void main() {
  group('Gateway identity headers', () {
    test('Gateway stores platform and userId', () {
      final gateway = Gateway(
        baseUrl: 'http://localhost:5140',
        platform: 'discord',
        userId: 'user123',
      );
      expect(gateway.platform, equals('discord'));
      expect(gateway.userId, equals('user123'));
    });

    test('Gateway identity fields default to null', () {
      final gateway = Gateway(baseUrl: 'http://localhost:5140');
      expect(gateway.platform, isNull);
      expect(gateway.userId, isNull);
    });
  });

  group('NitoriClient identity fields', () {
    test('NitoriClient stores platform and userId', () {
      final client = NitoriClient(
        baseUrl: 'http://localhost:5140',
        platform: 'discord',
        userId: 'user123',
        httpClient: _MockHttpClient(),
      );
      expect(client.platform, equals('discord'));
      expect(client.userId, equals('user123'));
      client.close();
    });

    test('NitoriClient passes identity to Gateway', () {
      final client = NitoriClient(
        baseUrl: 'http://localhost:5140',
        platform: 'telegram',
        userId: 'user456',
        httpClient: _MockHttpClient(),
      );
      expect(client.gateway.platform, equals('telegram'));
      expect(client.gateway.userId, equals('user456'));
      client.close();
    });

    test('NitoriClient identity fields default to null', () {
      final client = NitoriClient(
        baseUrl: 'http://localhost:5140',
        httpClient: _MockHttpClient(),
      );
      expect(client.platform, isNull);
      expect(client.userId, isNull);
      expect(client.gateway.platform, isNull);
      expect(client.gateway.userId, isNull);
      client.close();
    });
  });
}
