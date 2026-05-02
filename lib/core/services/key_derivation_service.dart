import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/db/database_helper.dart';
import 'encryption_service.dart';

/// Derives the AES-256 encryption key deterministically from the signed-in
/// user's Google account ID using HKDF-SHA256.
///
/// The same Google ID always produces the same 32-byte key on any device,
/// enabling cross-device vault restore without transmitting the key.
class KeyDerivationService {
  KeyDerivationService._();
  static final KeyDerivationService instance = KeyDerivationService._();

  static const _salt = 'credlock-v1-key-derivation';
  static const _info = 'credlock-aes-256-key';
  static const _keyAlias = 'credlock_aes_key';

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── HKDF-SHA256 ────────────────────────────────────────────────────────────

  /// HKDF extract step: HMAC-SHA256(salt, ikm) → pseudorandom key (PRK).
  Uint8List _hkdfExtract(Uint8List salt, Uint8List ikm) {
    final hmac = Hmac(sha256, salt);
    final digest = hmac.convert(ikm);
    return Uint8List.fromList(digest.bytes);
  }

  /// HKDF expand step: produces [length] bytes from PRK + info.
  Uint8List _hkdfExpand(Uint8List prk, Uint8List info, int length) {
    final hashLen = 32; // SHA-256 output length
    final n = (length / hashLen).ceil();
    final okm = <int>[];
    var t = Uint8List(0);
    for (var i = 1; i <= n; i++) {
      final hmac = Hmac(sha256, prk);
      final input = [...t, ...info, i];
      t = Uint8List.fromList(hmac.convert(input).bytes);
      okm.addAll(t);
    }
    return Uint8List.fromList(okm.sublist(0, length));
  }

  /// Derives a 32-byte AES-256 key from [googleId] using HKDF-SHA256.
  /// Pure function — no side effects.
  Uint8List deriveKey(String googleId) {
    final ikm = Uint8List.fromList(utf8.encode(googleId));
    final saltBytes = Uint8List.fromList(utf8.encode(_salt));
    final infoBytes = Uint8List.fromList(utf8.encode(_info));
    final prk = _hkdfExtract(saltBytes, ikm);
    return _hkdfExpand(prk, infoBytes, 32);
  }

  // ── Account initialisation with migration ──────────────────────────────────

  /// Derives the key for [googleId], handles migration from a legacy random
  /// key if one exists, then initialises [EncryptionService] with the derived key.
  Future<void> initForAccount(String googleId) async {
    final derivedKeyBytes = deriveKey(googleId);
    final derivedKeyEncoded = base64Url.encode(derivedKeyBytes);

    final existingKeyEncoded = await _secureStorage.read(key: _keyAlias);

    if (existingKeyEncoded != null && existingKeyEncoded != derivedKeyEncoded) {
      // A different key exists — migrate: re-encrypt all entries.
      await _migrateEntries(
        oldKeyEncoded: existingKeyEncoded,
        newKeyBytes: derivedKeyBytes,
      );
    }

    await EncryptionService.instance.initWithDerivedKey(derivedKeyBytes);
  }

  /// Re-encrypts all password entries from [oldKeyEncoded] to [newKeyBytes].
  Future<void> _migrateEntries({
    required String oldKeyEncoded,
    required Uint8List newKeyBytes,
  }) async {
    // Init encryption service with the OLD key to decrypt existing data.
    final oldKeyBytes = Uint8List.fromList(base64Url.decode(oldKeyEncoded));
    await EncryptionService.instance.initWithDerivedKey(oldKeyBytes);

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(DatabaseHelper.tablePasswords);

    // Init encryption service with the NEW key to re-encrypt.
    await EncryptionService.instance.initWithDerivedKey(newKeyBytes);

    final enc = EncryptionService.instance;

    // Re-encrypt each row's sensitive fields using old→new key.
    // We need to decrypt with old key first, so we temporarily re-init.
    await EncryptionService.instance.initWithDerivedKey(oldKeyBytes);
    final decryptedRows = rows.map((row) {
      final r = Map<String, dynamic>.from(row);
      for (final field in ['username', 'password', 'pin', 'url', 'name']) {
        if (r[field] != null && (r[field] as String).isNotEmpty) {
          r[field] = enc.decrypt(r[field] as String);
        }
      }
      return r;
    }).toList();

    // Now init with new key and re-encrypt.
    await EncryptionService.instance.initWithDerivedKey(newKeyBytes);
    for (final row in decryptedRows) {
      final updated = Map<String, dynamic>.from(row);
      for (final field in ['username', 'password', 'pin', 'url', 'name']) {
        if (updated[field] != null && (updated[field] as String).isNotEmpty) {
          updated[field] = enc.encrypt(updated[field] as String);
        }
      }
      await db.update(
        DatabaseHelper.tablePasswords,
        updated,
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }
}
