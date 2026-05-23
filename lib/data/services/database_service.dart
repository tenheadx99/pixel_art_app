import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../config/app_constants.dart';

class DatabaseService {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pixel_art_catalog (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        grid_width INTEGER NOT NULL,
        grid_height INTEGER NOT NULL,
        category TEXT,
        difficulty INTEGER DEFAULT 1,
        is_premium INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        times_completed INTEGER DEFAULT 0,
        last_played TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_artworks (
        id TEXT PRIMARY KEY,
        pixel_art_id TEXT NOT NULL,
        name TEXT NOT NULL,
        file_path TEXT,
        date_created TEXT NOT NULL,
        completion_percent INTEGER DEFAULT 100
      )
    ''');

    await db.execute('''
      CREATE TABLE in_progress (
        pixel_art_id TEXT PRIMARY KEY,
        grid_state TEXT NOT NULL,
        selected_number INTEGER DEFAULT 1,
        progress REAL DEFAULT 0.0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getCatalog() async {
    final db = await database;
    return db.query('pixel_art_catalog', orderBy: 'difficulty ASC, name ASC');
  }

  Future<void> insertCatalogItem(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert(
      'pixel_art_catalog',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    final db = await database;
    await db.update(
      'pixel_art_catalog',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementCompleted(String id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pixel_art_catalog SET times_completed = times_completed + 1, last_played = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  Future<void> saveArtwork(Map<String, dynamic> artwork) async {
    final db = await database;
    await db.insert(
      'saved_artworks',
      artwork,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSavedArtworks() async {
    final db = await database;
    return db.query('saved_artworks', orderBy: 'date_created DESC');
  }

  Future<void> deleteArtwork(String id) async {
    final db = await database;
    await db.delete('saved_artworks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveInProgress(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'in_progress',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getInProgress(String pixelArtId) async {
    final db = await database;
    final results = await db.query(
      'in_progress',
      where: 'pixel_art_id = ?',
      whereArgs: [pixelArtId],
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<void> deleteInProgress(String pixelArtId) async {
    final db = await database;
    await db.delete(
      'in_progress',
      where: 'pixel_art_id = ?',
      whereArgs: [pixelArtId],
    );
  }
}
