import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:finderly/database/local_db.dart';
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/services/file_service.dart';
import 'package:finderly/services/sync_service.dart';
import 'package:finderly/theme/folder_colors.dart';

class FolderProvider extends ChangeNotifier {
  static const _uuid = Uuid();
  final _db = LocalDB.instance;
  final _fileService = FileService();

  List<FolderModel> _folders = [];
  FolderModel? _currentFolder;
  bool _isLoading = false;
  final _parentStack = Queue<FolderModel>();

  UnmodifiableListView<FolderModel> get folders =>
      UnmodifiableListView(_folders);
  FolderModel? get currentFolder => _currentFolder;
  bool get isLoading => _isLoading;
  List<FolderModel> get breadcrumbs => _parentStack.toList();

  Future<void> loadFolders(String? parentId) async {
    _isLoading = true;
    notifyListeners();
    _folders = await _db.getFolders(parentId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createFolder(
      String name, FolderColor color, [String? parentId]) async {
    final now = DateTime.now();
    final folder = FolderModel(
      id: _uuid.v4(),
      name: name,
      parentId: parentId,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insertFolder(folder);
    SyncService.instance.markPending();
    await loadFolders(parentId);
  }

  Future<void> renameFolder(String id, String newName) async {
    final folder = await _db.getFolderById(id);
    if (folder == null) return;
    await _db.updateFolder(
        folder.copyWith(name: newName, updatedAt: DateTime.now()));
    SyncService.instance.markPending();
    await loadFolders(folder.parentId);
  }

  Future<void> changeFolderColor(String id, FolderColor color) async {
    final folder = await _db.getFolderById(id);
    if (folder == null) return;
    await _db.updateFolder(
        folder.copyWith(color: color, updatedAt: DateTime.now()));
    SyncService.instance.markPending();
    await loadFolders(folder.parentId);
  }

  Future<void> deleteFolder(String id) async {
    final folder = await _db.getFolderById(id);
    final parentId = folder?.parentId;

    // Recursively delete from database and get all affected folder IDs
    final deletedFolderIds = await _db.deleteFolder(id);

    // Clean up physical disk folders
    final appDir = await _fileService.getAppStorageDir();
    for (final fId in deletedFolderIds) {
      final dir = Directory(p.join(appDir, fId));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }

    SyncService.instance.markPending();
    await loadFolders(parentId);
  }

  Future<List<FolderModel>> getMergeCandidates(String sourceFolderId) async {
    return _db.getMergeCandidates(sourceFolderId);
  }

  Future<List<FolderModel>> getMoveCandidates({List<String> excludeFolderIds = const []}) async {
    return _db.getMoveCandidates(excludeFolderIds: excludeFolderIds);
  }

  Future<void> moveFolders(
    List<String> folderIds,
    String? targetParentId, {
    String? refreshParentId,
  }) async {
    await _db.moveFolders(folderIds, targetParentId);
    SyncService.instance.markPending();
    await loadFolders(refreshParentId);
  }

  Future<void> mergeFolders(
    String sourceFolderId,
    String targetFolderId, {
    String? refreshParentId,
  }) async {
    // 1. Physically move all source files to target folder on disk and update records
    final sourceFiles = await _db.getFilesByFolder(sourceFolderId);
    for (final file in sourceFiles) {
      final newPath = await _fileService.moveFileOnDisk(file.localPath, targetFolderId);
      final newName = p.basename(newPath);
      await _db.updateFile(file.copyWith(
        folderId: targetFolderId,
        localPath: newPath,
        name: newName,
      ));
    }

    // 2. Perform database merge for subfolders and clean source folder record
    await _db.mergeFolders(sourceFolderId, targetFolderId);

    // 3. Clean up source folder directory on disk if empty
    try {
      final appDir = await _fileService.getAppStorageDir();
      final sourceDir = Directory(p.join(appDir, sourceFolderId));
      if (await sourceDir.exists()) {
        await sourceDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Source folder disk cleanup notice: $e');
    }

    SyncService.instance.markPending();
    await loadFolders(refreshParentId);
  }

  void navigateToFolder(FolderModel folder) {
    if (_currentFolder != null) {
      _parentStack.addLast(_currentFolder!);
    }
    _currentFolder = folder;
    loadFolders(folder.id);
  }

  void navigateBack() {
    if (_parentStack.isEmpty) {
      _currentFolder = null;
      loadFolders(null);
    } else {
      _currentFolder = _parentStack.removeLast();
      loadFolders(_currentFolder!.id);
    }
  }
}
