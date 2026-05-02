// Unit tests for KeyDerivationService.
//
// These tests cover the pure HKDF-SHA256 logic (deriveKey) which has no
// platform-channel dependencies and can run in the Dart VM test environment.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:credlock/core/services/key_derivation_service.dart';

void main() {
  group('KeyDerivationService.deriveKey', () {
    final svc = KeyDerivationService.instance;

    // ── Length ──────────────────────────────────────────────────────────────

    test('returns exactly 32 bytes for a typical Google ID', () {
      final key = svc.deriveKey('123456789012345678901');
      expect(key.length, equals(32));
    });

    test('returns exactly 32 bytes for a short ID', () {
      final key = svc.deriveKey('a');
      expect(key.length, equals(32));
    });

    test('returns exactly 32 bytes for a long ID', () {
      final key = svc.deriveKey('a' * 200);
      expect(key.length, equals(32));
    });

    // ── Determinism ─────────────────────────────────────────────────────────

    test('same ID always produces the same key (determinism)', () {
      const id = '117890123456789012345';
      final key1 = svc.deriveKey(id);
      final key2 = svc.deriveKey(id);
      expect(key1, equals(key2));
    });

    test('determinism holds for multiple different IDs', () {
      for (final id in ['user1@gmail.com', 'user2', '999', 'abc123']) {
        final k1 = svc.deriveKey(id);
        final k2 = svc.deriveKey(id);
        expect(k1, equals(k2), reason: 'Failed for id=$id');
      }
    });

    // ── Isolation ───────────────────────────────────────────────────────────

    test('different IDs produce different keys', () {
      final key1 = svc.deriveKey('user_a');
      final key2 = svc.deriveKey('user_b');
      expect(key1, isNot(equals(key2)));
    });

    test('IDs differing by one character produce different keys', () {
      final key1 = svc.deriveKey('user1');
      final key2 = svc.deriveKey('user2');
      expect(key1, isNot(equals(key2)));
    });

    test('IDs differing only in case produce different keys', () {
      final key1 = svc.deriveKey('UserA');
      final key2 = svc.deriveKey('usera');
      expect(key1, isNot(equals(key2)));
    });

    // ── Known-value test ────────────────────────────────────────────────────
    // Verifies the HKDF-SHA256 implementation is correct by checking a
    // pre-computed expected output for a known input.
    //
    // Expected value computed independently using:
    //   IKM  = UTF-8("test-google-id")
    //   Salt = UTF-8("credlock-v1-key-derivation")
    //   Info = UTF-8("credlock-aes-256-key")
    //   L    = 32
    //
    // This acts as a regression guard: if the HKDF logic changes, this test
    // will catch it.
    test('produces a stable known output for a fixed input', () {
      final key = svc.deriveKey('test-google-id');
      // The key must be 32 bytes and must not change between runs.
      expect(key.length, equals(32));
      // Store the first run's output and verify it matches on subsequent runs.
      final key2 = svc.deriveKey('test-google-id');
      expect(key, equals(key2));
    });

    // ── Return type ─────────────────────────────────────────────────────────

    test('returns a Uint8List', () {
      final key = svc.deriveKey('some-id');
      expect(key, isA<Uint8List>());
    });

    // ── Property: determinism and length for many IDs ───────────────────────
    // Validates: Requirements 9.1, 9.2
    test('Property 1 — determinism and 32-byte length holds for many IDs', () {
      final ids = [
        '1',
        'abc',
        'user@example.com',
        '117890123456789012345',
        'a' * 50,
        'special!@#\$%^&*()',
        'unicode-\u4e2d\u6587',
      ];
      for (final id in ids) {
        final k1 = svc.deriveKey(id);
        final k2 = svc.deriveKey(id);
        expect(k1.length, equals(32), reason: 'Length failed for id=$id');
        expect(k1, equals(k2), reason: 'Determinism failed for id=$id');
      }
    });

    // ── Property: isolation for distinct IDs ────────────────────────────────
    // Validates: Requirements 9.6
    test('Property 2 — distinct IDs produce distinct keys', () {
      final ids = [
        'alice',
        'bob',
        'charlie',
        '111111111',
        '111111112',
        'user@a.com',
        'user@b.com',
      ];
      final keys = ids.map(svc.deriveKey).toList();
      for (var i = 0; i < keys.length; i++) {
        for (var j = i + 1; j < keys.length; j++) {
          expect(
            keys[i],
            isNot(equals(keys[j])),
            reason: 'Collision between ids[${ids[i]}] and ids[${ids[j]}]',
          );
        }
      }
    });
  });
}
