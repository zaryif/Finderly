import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:finderly/models/file_item_model.dart';

class FileService {
  static const _uuid = Uuid();

  /// Pick one or multiple files and copy them into the app's folder storage
  Future<List<FileItemModel>> importFiles(String folderId) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return [];

    final appDir = await getAppStorageDir();
    final folderDir = Directory(p.join(appDir, folderId));
    if (!folderDir.existsSync()) {
      await folderDir.create(recursive: true);
    }

    final imported = <FileItemModel>[];
    for (final pickedFile in result.files) {
      if (pickedFile.path == null) continue;
      final picked = File(pickedFile.path!);
      final fileName = pickedFile.name;
      final destPath = p.join(folderDir.path, fileName);

      // Copy file to local persistent storage
      await picked.copy(destPath);

      final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
      final stat = await File(destPath).stat();

      imported.add(
        FileItemModel(
          id: _uuid.v4(),
          name: fileName,
          folderId: folderId,
          localPath: destPath,
          mimeType: mimeType,
          sizeBytes: stat.size,
          createdAt: DateTime.now(),
          isDownloaded: true,
        ),
      );
    }

    return imported;
  }

  /// Rename file physically on filesystem
  Future<String> renameFileOnDisk(String currentPath, String newName) async {
    final currentFile = File(currentPath);
    if (!await currentFile.exists()) return currentPath;

    final dir = p.dirname(currentPath);
    final newPath = p.join(dir, newName);
    await currentFile.rename(newPath);
    return newPath;
  }

  /// Physically move file to new folder directory on disk, ensuring safe rename and collision handling
  Future<String> moveFileOnDisk(String currentPath, String newFolderId) async {
    final currentFile = File(currentPath);
    if (!await currentFile.exists()) return currentPath;

    final appDir = await getAppStorageDir();
    final targetDir = Directory(p.join(appDir, newFolderId));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final originalName = p.basename(currentPath);
    var newDest = p.join(targetDir.path, originalName);

    // If destination already exists with same name, generate unique name
    if (await File(newDest).exists() && newDest != currentPath) {
      final base = p.basenameWithoutExtension(originalName);
      final ext = p.extension(originalName);
      int counter = 1;
      while (await File(p.join(targetDir.path, '$base ($counter)$ext')).exists()) {
        counter++;
      }
      newDest = p.join(targetDir.path, '$base ($counter)$ext');
    }

    try {
      await currentFile.rename(newDest);
    } catch (_) {
      // Fallback for cross-filesystem moves
      await currentFile.copy(newDest);
      await currentFile.delete();
    }
    return newDest;
  }

  Future<void> deleteFileFromDisk(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> getAppStorageDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'Finderly');
  }

  IconData getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
    if (mimeType.startsWith('text/')) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color getFileIconColor(String mimeType) {
    if (mimeType.startsWith('image/')) return const Color(0xFF4A9EF5);
    if (mimeType.startsWith('video/')) return const Color(0xFFE74C3C);
    if (mimeType.startsWith('audio/')) return const Color(0xFF9B59B6);
    if (mimeType == 'application/pdf') return const Color(0xFFE74C3C);
    if (mimeType.startsWith('text/')) return const Color(0xFF2ECC71);
    return const Color(0xFF95A5A6);
  }
}
