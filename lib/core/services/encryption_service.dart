import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-CBC encryption service.
/// The key is generated once, stored in the device's secure keystore
/// (Android Keystore / iOS Secure Enclave), and reused on every launch.
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  static const _keyAlias = 'credlock_aes_key';

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Encrypter? _encrypter;
  bool _ready = false;

  /// Must be called once at app startup before any DB operations.
  Future<void> init() async {
    if (_ready) return;

    String? storedKey = await _secureStorage.read(key: _keyAlias);

    if (storedKey == null) {
      // Generate a cryptographically secure 256-bit key
      final keyBytes = List<int>.generate(
        32,
        (_) => Random.secure().nextInt(256),
      );
      storedKey = base64Url.encode(keyBytes);
      await _secureStorage.write(key: _keyAlias, value: storedKey);
    }

    final keyBytes = base64Url.decode(storedKey);
    final key = Key(Uint8List.fromList(keyBytes));
    _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    _ready = true;
  }

  /// Initialise with a caller-supplied 32-byte derived key.
  /// Used after Google Sign-In key derivation. Persists the key to
  /// flutter_secure_storage so it survives app restarts.
  Future<void> initWithDerivedKey(Uint8List keyBytes) async {
    assert(keyBytes.length == 32, 'Derived key must be exactly 32 bytes');
    final key = Key(keyBytes);
    _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encoded = base64Url.encode(keyBytes);
    await _secureStorage.write(key: _keyAlias, value: encoded);
    _ready = true;
  }

  /// Encrypt a plain-text string. Returns "iv:ciphertext" (both base64).
  /// Returns empty string if input is empty.
  String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    _assertReady();
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt a "iv:ciphertext" string back to plain text.
  /// Returns empty string if input is empty or null.
  String decrypt(String? cipherText) {
    if (cipherText == null || cipherText.isEmpty) return '';
    _assertReady();
    try {
      final parts = cipherText.split(':');
      if (parts.length != 2) return cipherText; // not encrypted (legacy row)
      final iv = IV.fromBase64(parts[0]);
      return _encrypter!.decrypt64(parts[1], iv: iv);
    } catch (_) {
      return ''; // corrupted or unreadable
    }
  }

  void _assertReady() {
    assert(_ready, 'EncryptionService.init() must be called before use.');
  }
}
