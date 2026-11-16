/// Unit tests for [eventAliases] and [expandEventAliases].
library;

import 'package:nitori_core/nitori_core.dart';
import 'package:test/test.dart';

void main() {
  group('eventAliases', () {
    test('message-created canonicalizes to message', () {
      expect(
        expandEventAliases('message-created'),
        equals(<String>['message-created', 'message']),
      );
    });

    test('guild-removed canonicalizes to guild-deleted', () {
      expect(
        expandEventAliases('guild-removed'),
        equals(<String>['guild-removed', 'guild-deleted']),
      );
    });

    test('guild-member-removed canonicalizes to guild-member-deleted', () {
      expect(
        expandEventAliases('guild-member-removed'),
        equals(<String>['guild-member-removed', 'guild-member-deleted']),
      );
    });

    test('unknown event type returns itself only', () {
      expect(
        expandEventAliases('login-added'),
        equals(<String>['login-added']),
      );
      expect(
        expandEventAliases('channel-updated'),
        equals(<String>['channel-updated']),
      );
      expect(
        expandEventAliases('reaction-added'),
        equals(<String>['reaction-added']),
      );
    });

    test('canonical member expands to the whole group', () {
      expect(
        expandEventAliases('message'),
        equals(<String>['message-created', 'message']),
      );
    });
  });
}
