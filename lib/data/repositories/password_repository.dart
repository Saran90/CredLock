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

  /// Loads tag IDs for every entry in one query and returns a map of
  /// entry_id → [tag_id, ...].
  Future<Map<int, List<int>>> _loadAllTagIds(Database db) async {
    final rows = await db.query(DatabaseHelper.tableEntryTags);
    final map = <int, List<int>>{};
    for (final row in rows) {
      final entryId = row['entry_id'] as int;
      final tagId = row['tag_id'] as int;
      map.putIfAbsent(entryId, () => []).add(tagId);
    }
    return map;
  }

  /// Loads tag IDs for a single entry.
  Future<List<int>> _loadTagIdsForEntry(Database db, int entryId) async {
    final rows = await db.query(
      DatabaseHelper.tableEntryTags,
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
    return rows.map((r) => r['tag_id'] as int).toList();
  }

  /// Replaces all tag associations for [entryId] with [tagIds].
  Future<void> _saveTagIds(
    Database db,
    int entryId,
    List<int> tagIds, {
    Transaction? txn,
  }) async {
    final executor = txn ?? db;
    // Delete existing associations for this entry.
    await executor.delete(
      DatabaseHelper.tableEntryTags,
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
    // Insert new associations.
    for (final tagId in tagIds) {
      await executor.insert(
        DatabaseHelper.tableEntryTags,
        {'entry_id': entryId, 'tag_id': tagId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<PasswordEntry> insert(PasswordEntry entry) async {
    final db = await _db;
    late int id;
    await db.transaction((txn) async {
      id = await txn.insert(
        DatabaseHelper.tablePasswords,
        _encryptRow(entry.toMap()),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _saveTagIds(db, id, entry.tagIds, txn: txn);
    });
    return entry.copyWith(id: id);
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<PasswordEntry>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tablePasswords,
      orderBy: 'created_at DESC',
    );
    final tagMap = await _loadAllTagIds(db);
    return rows.map((r) {
      final decrypted = _decryptRow(r);
      final entryId = decrypted['id'] as int?;
      return PasswordEntry.fromMap(
        decrypted,
        tagIds: entryId != null ? (tagMap[entryId] ?? []) : [],
      );
    }).toList();
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
    final tagIds = await _loadTagIdsForEntry(db, id);
    return PasswordEntry.fromMap(_decryptRow(rows.first), tagIds: tagIds);
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
    assert(entry.id != null, 'Cannot update a PasswordEntry without an id');
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        DatabaseHelper.tablePasswords,
        _encryptRow(entry.toMap()),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      await _saveTagIds(db, entry.id!, entry.tagIds, txn: txn);
    });
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Deletes the entry. The entry_tags rows are removed automatically by the
  /// ON DELETE CASCADE foreign-key constraint.
  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(
      DatabaseHelper.tablePasswords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Favorite toggle ───────────────────────────────────────────────────────

  /// Flips the [isFavorite] flag for a single entry without touching any
  /// encrypted fields or tag associations. Returns the updated entry.
  Future<PasswordEntry> toggleFavorite(PasswordEntry entry) async {
    final db = await _db;
    final updated = entry.copyWith(isFavorite: !entry.isFavorite);
    await db.update(
      DatabaseHelper.tablePasswords,
      {'is_favorite': updated.isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    return updated;
  }
}
