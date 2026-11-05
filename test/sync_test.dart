import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:finderly/services/sync_service.dart';
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/models/file_item_model.dart';
import 'package:finderly/theme/folder_colors.dart';

void main() {
  group('SyncService models and structures', () {
    test('DiscoveredPeer formats endpoint correctly', () {
      final peer = DiscoveredPeer(
        id: '192.168.1.100:8765',
        ip: '192.168.1.100',
        port: 8765,
        deviceName: 'MacBook Pro',
        lastSeen: DateTime.now(),
      );

      expect(peer.endpoint, '192.168.1.100:8765');
      expect(peer.deviceName, 'MacBook Pro');
    });

    test('SyncStats calculates properties', () {
      final stats = SyncStats(
        foldersSynced: 3,
        filesDownloaded: 5,
        filesUploaded: 2,
        totalBytesTransferred: 1048576,
        summary: 'Synced: 3 folders, 5 files received',
      );

      expect(stats.foldersSynced, 3);
      expect(stats.filesDownloaded, 5);
      expect(stats.filesUploaded, 2);
      expect(stats.totalBytesTransferred, 1048576);
      expect(stats.summary, 'Synced: 3 folders, 5 files received');
    });
  });

  group('Vault archive binary format serialization', () {
    test('FNDR package binary header roundtrip', () async {
      final testFolder = FolderModel(
        id: 'f-test-1',
        name: 'University Notes',
        parentId: null,
        color: FolderColor.green,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDownloaded: true,
      );

      final manifestMap = {
        'version': 1,
        'app': 'Finderly',
        'exportedAt': DateTime.now().toIso8601String(),
        'deviceName': 'Test Device',
        'folders': [testFolder.toMap()],
        'files': [],
      };

      final manifestBytes = utf8.encode(jsonEncode(manifestMap));

      final header = ByteData(12);
      header.setUint8(0, 0x46); // 'F'
      header.setUint8(1, 0x4E); // 'N'
      header.setUint8(2, 0x44); // 'D'
      header.setUint8(3, 0x52); // 'R'
      header.setUint32(4, 1, Endian.big);
      header.setUint32(8, manifestBytes.length, Endian.big);

      final fullPackage = Uint8List(12 + manifestBytes.length);
      fullPackage.setRange(0, 12, header.buffer.asUint8List());
      fullPackage.setRange(12, 12 + manifestBytes.length, manifestBytes);

      // Verify header unpacking
      final readHeader = ByteData.sublistView(fullPackage, 0, 12);
      final magic = String.fromCharCodes(fullPackage.sublist(0, 4));
      final version = readHeader.getUint32(4, Endian.big);
      final readLen = readHeader.getUint32(8, Endian.big);

      expect(magic, 'FNDR');
      expect(version, 1);
      expect(readLen, manifestBytes.length);

      final readManifestBytes = fullPackage.sublist(12, 12 + readLen);
      final readJson = jsonDecode(utf8.decode(readManifestBytes)) as Map<String, dynamic>;
      final restoredFolders = (readJson['folders'] as List).map((m) => FolderModel.fromMap(m)).toList();

      expect(restoredFolders.length, 1);
      expect(restoredFolders.first.name, 'University Notes');
      expect(restoredFolders.first.color, FolderColor.green);
    });
  });
}

