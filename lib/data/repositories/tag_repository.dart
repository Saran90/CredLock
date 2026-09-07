import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/tag.dart';

/// CRUD access for user-defined [Tag]s.
///
/// Tags are stored in the [DatabaseHelper.tableTags] table.
/// Membership (which entries carry a tag) lives in the
/// [DatabaseHelper.tableEntryTags] junction table and is managed by
/// [PasswordRepository].
class TagRepository {
  TagRepository._();
  static final TagRepository instance = TagRepository._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  // ── Create ────────────────────────────────────────────────────────────────

  /// Inserts a new tag and returns it with its assigned [Tag.id].
  Future<Tag> insert(Tag tag) async {
    final db = await _db;
    final id = await db.insert(
      DatabaseHelper.tableTags,
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return tag.copyWith(id: id);
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<Tag>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableTags,
      orderBy: 'name ASC',
    );
    return rows.map(Tag.fromMap).toList();
  }

  Future<Tag?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseHelper.tableTags,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Tag.fromMap(rows.first);
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<void> update(Tag tag) async {
    assert(tag.id != null, 'Cannot update a Tag without an id');
    final db = await _db;
    await db.update(
      DatabaseHelper.tableTags,
      tag.toMap(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Deletes the tag. All [DatabaseHelper.tableEntryTags] rows that reference
  /// this tag are removed automatically via the ON DELETE CASCADE constraint.
  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(
      DatabaseHelper.tableTags,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
