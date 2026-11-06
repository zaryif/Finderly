import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/models/file_item_model.dart';

class LocalDB {
  LocalDB._();
  static final instance = LocalDB._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dbPath, 'finderly.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parentId TEXT,
            color TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            isDownloaded INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE files (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            folderId TEXT NOT NULL,
            localPath TEXT NOT NULL,
            cloudUrl TEXT,
            mimeType TEXT NOT NULL,
            sizeBytes INTEGER NOT NULL,
            createdAt INTEGER NOT NULL,
            isDownloaded INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (folderId) REFERENCES folders (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
      },
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    return db;
  }

  // --- Folders ---

  Future<void> insertFolder(FolderModel folder) async {
    final db = await database;
    await db.insert('folders', folder.toMap());
  }

  Future<void> updateFolder(FolderModel folder) async {
    final db = await database;
    await db.update('folders', folder.toMap(),
        where: 'id = ?', whereArgs: [folder.id]);
  }

  /// Recursively delete a folder, all its nested subfolders, and all contained files
  Future<List<String>> deleteFolder(String id) async {
    final db = await database;
    final allFolderIds = <String>[id];
    final queue = <String>[id];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final children = await db.query(
        'folders',
        columns: ['id'],
        where: 'parentId = ?',
        whereArgs: [current],
      );
      for (final child in children) {
        final childId = child['id'] as String;
        allFolderIds.add(childId);
        queue.add(childId);
      }
    }

    for (final fId in allFolderIds) {
      await db.delete('files', where: 'folderId = ?', whereArgs: [fId]);
      await db.delete('folders', where: 'id = ?', whereArgs: [fId]);
    }

    return allFolderIds;
  }

  Future<List<FolderModel>> getFolders(String? parentId) async {
    final db = await database;
    final maps = await db.query(
      'folders',
      where: parentId == null ? 'parentId IS NULL' : 'parentId = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'name ASC',
    );
    return maps.map(FolderModel.fromMap).toList();
  }

  Future<FolderModel?> getFolderById(String id) async {
    final db = await database;
    final maps =
        await db.query('folders', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isEmpty ? null : FolderModel.fromMap(maps.first);
  }

  Future<List<FolderModel>> searchFolders(String query) async {
    final db = await database;
    final maps = await db.query(
      'folders',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map(FolderModel.fromMap).toList();
  }

  /// Get candidate target folders for merge, excluding the source folder and all its descendants
  Future<List<FolderModel>> getMergeCandidates(String sourceFolderId) async {
    final db = await database;
    final excludedIds = <String>{sourceFolderId};
    final queue = <String>[sourceFolderId];

    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      final children = await db.query(
        'folders',
        columns: ['id'],
        where: 'parentId = ?',
        whereArgs: [cur],
      );
      for (final c in children) {
        final cid = c['id'] as String;
        excludedIds.add(cid);
        queue.add(cid);
      }
    }

    final all = await getAllFolders();
    return all.where((f) => !excludedIds.contains(f.id)).toList();
  }

  /// Merges all files and subfolders from sourceFolderId into targetFolderId, then removes sourceFolderId
  Future<void> mergeFolders(String sourceFolderId, String targetFolderId) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Move all files from source to target
      await txn.update(
        'files',
        {'folderId': targetFolderId},
        where: 'folderId = ?',
        whereArgs: [sourceFolderId],
      );

      // 2. Move direct subfolders from source to target
      await txn.update(
        'folders',
        {'parentId': targetFolderId},
        where: 'parentId = ?',
        whereArgs: [sourceFolderId],
      );

      // 3. Delete the source folder record
      await txn.delete(
        'folders',
        where: 'id = ?',
        whereArgs: [sourceFolderId],
      );

      // 4. Update timestamp of target folder
      await txn.update(
        'folders',
        {'updatedAt': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [targetFolderId],
      );
    });
  }

  /// Move multiple files into targetFolderId
  Future<void> moveFiles(List<String> fileIds, String targetFolderId) async {
    if (fileIds.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final id in fileIds) {
        await txn.update(
          'files',
          {'folderId': targetFolderId},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await txn.update(
        'folders',
        {'updatedAt': now},
        where: 'id = ?',
        whereArgs: [targetFolderId],
      );
    });
  }

  /// Move multiple folders into targetParentId (null means root/home)
  Future<void> moveFolders(List<String> folderIds, String? targetParentId) async {
    if (folderIds.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final id in folderIds) {
        await txn.update(
          'folders',
          {'parentId': targetParentId, 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      if (targetParentId != null) {
        await txn.update(
          'folders',
          {'updatedAt': now},
          where: 'id = ?',
          whereArgs: [targetParentId],
        );
      }
    });
  }

  /// Get candidate destination folders for moving, excluding the given folderIds and all their descendants
  Future<List<FolderModel>> getMoveCandidates({List<String> excludeFolderIds = const []}) async {
    final db = await database;
    final excluded = <String>{...excludeFolderIds};
    final queue = <String>[...excludeFolderIds];

    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      final children = await db.query(
        'folders',
        columns: ['id'],
        where: 'parentId = ?',
        whereArgs: [cur],
      );
      for (final c in children) {
        final cid = c['id'] as String;
        excluded.add(cid);
        queue.add(cid);
      }
    }

    final all = await getAllFolders();
    return all.where((f) => !excluded.contains(f.id)).toList();
  }

  // --- Files ---

  Future<void> insertFile(FileItemModel file) async {
    final db = await database;
    await db.insert('files', file.toMap());
  }

  Future<void> updateFile(FileItemModel file) async {
    final db = await database;
    await db.update('files', file.toMap(),
        where: 'id = ?', whereArgs: [file.id]);
  }

  Future<void> deleteFile(String id) async {
    final db = await database;
    await db.delete('files', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FileItemModel>> getFilesByFolder(String folderId) async {
    final db = await database;
    final maps = await db.query(
      'files',
      where: 'folderId = ?',
      whereArgs: [folderId],
      orderBy: 'name ASC',
    );
    return maps.map(FileItemModel.fromMap).toList();
  }

  Future<FileItemModel?> getFileById(String id) async {
    final db = await database;
    final maps =
        await db.query('files', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isEmpty ? null : FileItemModel.fromMap(maps.first);
  }

  Future<List<FileItemModel>> searchFiles(String query) async {
    final db = await database;
    final maps = await db.query(
      'files',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map(FileItemModel.fromMap).toList();
  }

  // --- Real Sync & Vault Operations ---

  Future<List<FolderModel>> getAllFolders() async {
    final db = await database;
    final maps = await db.query('folders', orderBy: 'name ASC');
    return maps.map(FolderModel.fromMap).toList();
  }

  Future<List<FileItemModel>> getAllFiles() async {
    final db = await database;
    final maps = await db.query('files', orderBy: 'name ASC');
    return maps.map(FileItemModel.fromMap).toList();
  }

  Future<void> upsertFolder(FolderModel folder) async {
    final db = await database;
    await db.insert('folders', folder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertFile(FileItemModel file) async {
    final db = await database;
    await db.insert('files', file.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;
    final folderCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM folders')) ??
        0;
    final fileCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM files')) ??
        0;
    final totalBytes = Sqflite.firstIntValue(await db
            .rawQuery('SELECT SUM(sizeBytes) FROM files')) ??
        0;
    return {
      'folderCount': folderCount,
      'fileCount': fileCount,
      'totalBytes': totalBytes,
    };
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('settings',
        columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    return maps.isEmpty ? null : maps.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
