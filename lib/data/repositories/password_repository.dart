import 'package:sqflite/sqflite.dart';
import '../../core/services/encryption_service.dart';
import '../db/database_helper.dart';
import '../models/password_entry.dart';

/// Sensitive fields that are AES-encrypted before storage.
/// Non-sensitive fields (id, category, package_name, app_icon_base64,
/// created_at) are stored as plain text so search/sort still works.
const _sensitiveFields = ['username', 'password', 'pin', 'url', 'name'];

class PasswordRepository {
  PasswordRepository._();
  static final PasswordRepository instance = PasswordRepository._();

  final _enc = EncryptionService.instance;

  Future<Database> get _db async => DatabaseHelper.instance.database;

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _encryptRow(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    for (final field in _sensitiveFields) {
      if (result.containsKey(field) && result[field] != null) {
        result[field] = _enc.encrypt(result[field].toString());
      }
    }
    return result;
  }

  Map<String, dynamic> _decryptRow(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    for (final field in _sensitiveFields) {
      if (result.containsKey(field) && result[field] != null) {
        result[field] = _enc.decrypt(result[field].toString());
      }
    }
    return result;
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<PasswordEntry> insert(PasswordEntry entry) async {
    final db = await _db;
    final id = await db.insert(
      DatabaseHelper.tablePasswords,
      _encryptRow(entry.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return entry.copyWith(id: id);
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<PasswordEntry>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tablePasswords,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => PasswordEntry.fromMap(_decryptRow(r))).toList();
  }

  Future<PasswordEntry?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tablePasswords,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PasswordEntry.fromMap(_decryptRow(rows.first));
  }

  /// Search is done in-memory after decryption since fields are encrypted.
  Future<List<PasswordEntry>> search(String query) async {
    final all = await getAll();
    final q = query.toLowerCase();
    return all
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.username.toLowerCase().contains(q) ||
              e.url.toLowerCase().contains(q),
        )
        .toList();
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<void> update(PasswordEntry entry) async {
    final db = await _db;
    await db.update(
      DatabaseHelper.tablePasswords,
      _encryptRow(entry.toMap()),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(
      DatabaseHelper.tablePasswords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
