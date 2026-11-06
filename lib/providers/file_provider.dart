import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:finderly/database/local_db.dart';
import 'package:finderly/models/file_item_model.dart';
import 'package:finderly/services/file_service.dart';
import 'package:finderly/services/sync_service.dart';

class FileProvider extends ChangeNotifier {
  final _db = LocalDB.instance;
  final _fileService = FileService();

  List<FileItemModel> _files = [];
  bool _isLoading = false;

  UnmodifiableListView<FileItemModel> get files =>
      UnmodifiableListView(_files);
  bool get isLoading => _isLoading;

  Future<void> loadFiles(String folderId) async {
    _isLoading = true;
    notifyListeners();
    _files = await _db.getFilesByFolder(folderId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> importFiles(String folderId) async {
    final importedList = await _fileService.importFiles(folderId);
    for (final file in importedList) {
      await _db.insertFile(file);
    }
    if (importedList.isNotEmpty) {
      SyncService.instance.markPending();
      await loadFiles(folderId);
    }
  }

  Future<void> renameFile(String id, String newName) async {
    final file = await _db.getFileById(id);
    if (file == null) return;

    // Rename on disk first
    final newPath = await _fileService.renameFileOnDisk(file.localPath, newName);
    await _db.updateFile(file.copyWith(name: newName, localPath: newPath));
    SyncService.instance.markPending();
    await loadFiles(file.folderId);
  }

  Future<void> deleteFile(String id) async {
    final file = await _db.getFileById(id);
    if (file == null) return;
    await _fileService.deleteFileFromDisk(file.localPath);
    await _db.deleteFile(id);
    SyncService.instance.markPending();
    await loadFiles(file.folderId);
  }

  Future<void> moveFiles(List<String> fileIds, String targetFolderId, {String? currentFolderId}) async {
    for (final id in fileIds) {
      final file = await _db.getFileById(id);
      if (file == null) continue;
      final newPath = await _fileService.moveFileOnDisk(file.localPath, targetFolderId);
      final newName = p.basename(newPath);
      await _db.updateFile(file.copyWith(
        folderId: targetFolderId,
        localPath: newPath,
        name: newName,
      ));
    }
    SyncService.instance.markPending();
    if (currentFolderId != null) {
      await loadFiles(currentFolderId);
    }
  }

  Future<void> toggleDownload(String id) async {
    final file = await _db.getFileById(id);
    if (file == null) return;
    final updated = file.copyWith(isDownloaded: !file.isDownloaded);
    await _db.updateFile(updated);
    await loadFiles(file.folderId);
  }
}
