import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:finderly/database/local_db.dart';
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/models/file_item_model.dart';
import 'package:finderly/services/file_service.dart';

enum SyncStatus { idle, syncing, synced, serverRunning, offline, error }

class DiscoveredPeer {
  final String id;
  final String ip;
  final int port;
  final String deviceName;
  final DateTime lastSeen;

  DiscoveredPeer({
    required this.id,
    required this.ip,
    required this.port,
    required this.deviceName,
    required this.lastSeen,
  });

  String get endpoint => '$ip:$port';
}

class SyncStats {
  final int foldersSynced;
  final int filesDownloaded;
  final int filesUploaded;
  final int totalBytesTransferred;
  final String summary;

  SyncStats({
    this.foldersSynced = 0,
    this.filesDownloaded = 0,
    this.filesUploaded = 0,
    this.totalBytesTransferred = 0,
    this.summary = '',
  });
}

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._();
  SyncService._();

  static const int defaultHttpPort = 8765;
  static const int defaultBeaconPort = 8766;

  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncTime;
  String? _syncMessage;
  double _progress = 0.0;
  int _pendingChanges = 0;

  HttpServer? _server;
  RawDatagramSocket? _beaconSocket;
  Timer? _beaconBroadcastTimer;
  Timer? _peerCleanupTimer;

  String? _localIp;
  int _port = defaultHttpPort;
  String _deviceName = '';
  bool _isServerRunning = false;

  final Map<String, DiscoveredPeer> _peers = {};

  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncMessage => _syncMessage;
  double get progress => _progress;
  int get pendingChanges => _pendingChanges;
  String? get localIp => _localIp;
  int get port => _port;
  String get deviceName => _deviceName;
  bool get isServerRunning => _isServerRunning;
  List<DiscoveredPeer> get discoveredPeers => _peers.values.toList();

  // ==========================================
  // INITIALIZATION & LIFECYCLE
  // ==========================================

  Future<void> initialize() async {
    try {
      _deviceName = await _loadDeviceName();
    } catch (_) {
      _deviceName = 'Finderly Device';
    }
    try {
      await _detectLocalIp();
    } catch (_) {}
    try {
      await startServer();
    } catch (_) {}
    try {
      await startDiscovery();
    } catch (_) {}
  }

  Future<String> _loadDeviceName() async {
    final saved = await LocalDB.instance.getSetting('device_name');
    if (saved != null && saved.trim().isNotEmpty) {
      return saved;
    }
    String os = Platform.operatingSystem;
    String host = Platform.localHostname;
    if (host.isEmpty) host = 'Device';
    return '$host ($os)';
  }

  Future<void> updateDeviceName(String newName) async {
    if (newName.trim().isEmpty) return;
    _deviceName = newName.trim();
    await LocalDB.instance.setSetting('device_name', _deviceName);
    notifyListeners();
  }

  Future<void> _detectLocalIp() async {
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('vmnet') ||
            name.contains('vbox') ||
            name.contains('docker') ||
            name.contains('dummy')) {
          continue;
        }
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            _localIp = addr.address;
            notifyListeners();
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[SyncService] IP detection error: $e');
    }
    _localIp ??= '127.0.0.1';
  }

  // ==========================================
  // LOCAL HTTP SYNC SERVER
  // ==========================================

  Future<bool> startServer({int port = defaultHttpPort}) async {
    if (_server != null) return true;
    _port = port;

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        _port,
        shared: true,
      );
      _isServerRunning = true;
      _server!.listen(_handleHttpRequest, onError: (e) {
        debugPrint('[SyncService] Server error: $e');
      });

      _status = SyncStatus.serverRunning;
      _syncMessage = 'Local sync server active on $_localIp:$_port';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[SyncService] Failed to bind server on port $_port: $e');
      _isServerRunning = false;
      _status = SyncStatus.error;
      _syncMessage = 'Failed to start sync server: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _isServerRunning = false;
    _status = SyncStatus.idle;
    notifyListeners();
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    // Add CORS headers for cross-platform LAN queries
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    try {
      if (path == '/api/v1/info' && request.method == 'GET') {
        final stats = await LocalDB.instance.getDatabaseStats();
        final body = {
          'app': 'Finderly',
          'version': '1.0.0',
          'deviceName': _deviceName,
          'foldersCount': stats['folderCount'],
          'filesCount': stats['fileCount'],
          'totalBytes': stats['totalBytes'],
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(body));
        await request.response.close();
        return;
      }

      if (path == '/api/v1/manifest' && request.method == 'GET') {
        final folders = await LocalDB.instance.getAllFolders();
        final files = await LocalDB.instance.getAllFiles();

        final body = {
          'deviceName': _deviceName,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'folders': folders.map((f) => f.toMap()).toList(),
          'files': files.map((f) => f.toMap()).toList(),
        };

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(body));
        await request.response.close();
        return;
      }

      if (path == '/api/v1/file' && request.method == 'GET') {
        final fileId = request.uri.queryParameters['id'];
        if (fileId == null || fileId.isEmpty) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('Missing file id');
          await request.response.close();
          return;
        }

        final fileItem = await LocalDB.instance.getFileById(fileId);
        if (fileItem == null) {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('File not found in database');
          await request.response.close();
          return;
        }

        final fileOnDisk = File(fileItem.localPath);
        if (!await fileOnDisk.exists()) {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('File data missing on disk');
          await request.response.close();
          return;
        }

        final mimeParts = fileItem.mimeType.split('/');
        final primary = mimeParts.isNotEmpty ? mimeParts[0] : 'application';
        final sub = mimeParts.length > 1 ? mimeParts[1] : 'octet-stream';

        request.response.headers.contentType = ContentType(primary, sub);
        request.response.headers.contentLength = await fileOnDisk.length();
        request.response.headers.add(
          'Content-Disposition',
          'inline; filename="${Uri.encodeComponent(fileItem.name)}"',
        );

        await request.response.addStream(fileOnDisk.openRead());
        await request.response.close();
        return;
      }

      if (path == '/api/v1/upload' && request.method == 'POST') {
        // Direct file upload from peer
        final folderId = request.uri.queryParameters['folderId'];
        final fileName = request.uri.queryParameters['fileName'];
        final fileId = request.uri.queryParameters['fileId'];
        final mimeType = request.uri.queryParameters['mimeType'] ??
            'application/octet-stream';

        if (folderId == null || fileName == null || fileId == null) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('Missing folderId, fileName, or fileId');
          await request.response.close();
          return;
        }

        final appDir = await FileService().getAppStorageDir();
        final folderDir = Directory(p.join(appDir, folderId));
        if (!await folderDir.exists()) {
          await folderDir.create(recursive: true);
        }

        final destPath = p.join(folderDir.path, fileName);
        final sink = File(destPath).openWrite();
        await for (final chunk in request) {
          sink.add(chunk);
        }
        await sink.close();

        final stat = await File(destPath).stat();
        final model = FileItemModel(
          id: fileId,
          name: fileName,
          folderId: folderId,
          localPath: destPath,
          mimeType: mimeType,
          sizeBytes: stat.size,
          createdAt: DateTime.now(),
          isDownloaded: true,
        );
        await LocalDB.instance.upsertFile(model);

        request.response.statusCode = HttpStatus.created;
        request.response.write(jsonEncode({'status': 'ok', 'id': fileId}));
        await request.response.close();
        return;
      }

      // Default 404
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Finderly API endpoint not found');
      await request.response.close();
    } catch (e) {
      debugPrint('[SyncService] HTTP request handling error: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Internal server error: $e');
      await request.response.close();
    }
  }

  // ==========================================
  // UDP BEACON & PEER DISCOVERY
  // ==========================================

  Future<void> startDiscovery() async {
    try {
      _beaconSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        defaultBeaconPort,
        reuseAddress: true,
        reusePort: false,
      );
      _beaconSocket!.broadcastEnabled = true;

      _beaconSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _beaconSocket!.receive();
          if (datagram != null) {
            _handleBeaconPacket(datagram);
          }
        }
      });

      // Broadcast beacon every 3 seconds
      _beaconBroadcastTimer?.cancel();
      _beaconBroadcastTimer =
          Timer.periodic(const Duration(seconds: 3), (_) => _sendBeacon());

      // Periodically clean up stale peers (older than 10 seconds)
      _peerCleanupTimer?.cancel();
      _peerCleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        final now = DateTime.now();
        final expired = <String>[];
        _peers.forEach((key, peer) {
          if (now.difference(peer.lastSeen).inSeconds > 10) {
            expired.add(key);
          }
        });
        if (expired.isNotEmpty) {
          for (final key in expired) {
            _peers.remove(key);
          }
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('[SyncService] UDP Discovery could not bind: $e');
    }
  }

  void _sendBeacon() {
    if (_beaconSocket == null || _localIp == null) return;
    try {
      final message = 'FINDERLY_BEACON:$_localIp:$_port:$_deviceName';
      final bytes = utf8.encode(message);
      _beaconSocket!.send(
        bytes,
        InternetAddress('255.255.255.255'),
        defaultBeaconPort,
      );
    } catch (_) {}
  }

  void _handleBeaconPacket(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data).trim();
      if (!text.startsWith('FINDERLY_BEACON:')) return;

      final parts = text.split(':');
      if (parts.length < 4) return;

      final senderIp = parts[1];
      final senderPort = int.tryParse(parts[2]) ?? defaultHttpPort;
      final senderName = parts.sublist(3).join(':');

      // Do not list self
      if (senderIp == _localIp && senderPort == _port) return;

      final key = '$senderIp:$senderPort';
      _peers[key] = DiscoveredPeer(
        id: key,
        ip: senderIp,
        port: senderPort,
        deviceName: senderName,
        lastSeen: DateTime.now(),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> stopDiscovery() async {
    _beaconBroadcastTimer?.cancel();
    _peerCleanupTimer?.cancel();
    _beaconSocket?.close();
    _beaconSocket = null;
    _peers.clear();
    notifyListeners();
  }

  // ==========================================
  // REAL TWO-WAY PEER SYNCHRONIZATION
  // ==========================================

  Future<SyncStats> syncWithPeer(String peerIp, {int port = defaultHttpPort}) async {
    if (_status == SyncStatus.syncing) {
      throw Exception('A sync operation is already in progress');
    }

    _status = SyncStatus.syncing;
    _progress = 0.05;
    _syncMessage = 'Connecting to $peerIp:$port...';
    notifyListeners();

    int foldersSynced = 0;
    int filesDownloaded = 0;
    int filesUploaded = 0;
    int totalBytesTransferred = 0;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      // 1. Fetch remote manifest
      _syncMessage = 'Retrieving remote file index...';
      _progress = 0.15;
      notifyListeners();

      final manifestUri = Uri.parse('http://$peerIp:$port/api/v1/manifest');
      final manifestReq = await client.getUrl(manifestUri);
      final manifestRes = await manifestReq.close();

      if (manifestRes.statusCode != HttpStatus.ok) {
        throw Exception(
            'Remote device returned status code ${manifestRes.statusCode}');
      }

      final manifestBody = await manifestRes.transform(utf8.decoder).join();
      final manifestData = jsonDecode(manifestBody) as Map<String, dynamic>;

      final remoteFoldersRaw = manifestData['folders'] as List? ?? [];
      final remoteFilesRaw = manifestData['files'] as List? ?? [];

      final remoteFolders =
          remoteFoldersRaw.map((m) => FolderModel.fromMap(m)).toList();
      final remoteFiles =
          remoteFilesRaw.map((m) => FileItemModel.fromMap(m)).toList();

      // 2. Load local state
      _syncMessage = 'Comparing folders & files...';
      _progress = 0.25;
      notifyListeners();

      final localFolders = await LocalDB.instance.getAllFolders();
      final localFiles = await LocalDB.instance.getAllFiles();

      final localFolderMap = {for (var f in localFolders) f.id: f};
      final localFileMap = {for (var f in localFiles) f.id: f};

      // 3. Reconcile Folders (Pull from remote)
      for (final rFolder in remoteFolders) {
        final lFolder = localFolderMap[rFolder.id];
        if (lFolder == null ||
            rFolder.updatedAt.isAfter(lFolder.updatedAt)) {
          await LocalDB.instance.upsertFolder(rFolder);
          foldersSynced++;
        }
      }

      // 4. Download missing or updated files from peer
      final appStorageDir = await FileService().getAppStorageDir();
      final filesToDownload = <FileItemModel>[];

      for (final rFile in remoteFiles) {
        final lFile = localFileMap[rFile.id];
        bool needDownload = false;

        if (lFile == null) {
          needDownload = true;
        } else {
          final localFileDisk = File(lFile.localPath);
          if (!await localFileDisk.exists() ||
              localFileDisk.lengthSync() != rFile.sizeBytes) {
            needDownload = true;
          }
        }

        if (needDownload) {
          filesToDownload.add(rFile);
        }
      }

      int totalItems = filesToDownload.length;
      int processedItems = 0;

      for (final rFile in filesToDownload) {
        processedItems++;
        _syncMessage =
            'Downloading ($processedItems/$totalItems) ${rFile.name}...';
        _progress = 0.25 + (0.50 * (processedItems / (totalItems > 0 ? totalItems : 1)));
        notifyListeners();

        final folderDir = Directory(p.join(appStorageDir, rFile.folderId));
        if (!await folderDir.exists()) {
          await folderDir.create(recursive: true);
        }

        final targetPath = p.join(folderDir.path, rFile.name);
        final fileUri =
            Uri.parse('http://$peerIp:$port/api/v1/file?id=${rFile.id}');
        final fileReq = await client.getUrl(fileUri);
        final fileRes = await fileReq.close();

        if (fileRes.statusCode == HttpStatus.ok) {
          final targetFile = File(targetPath);
          final sink = targetFile.openWrite();
          await for (final chunk in fileRes) {
            sink.add(chunk);
          }
          await sink.close();

          final stat = await targetFile.stat();
          final updatedModel = FileItemModel(
            id: rFile.id,
            name: rFile.name,
            folderId: rFile.folderId,
            localPath: targetPath,
            mimeType: rFile.mimeType,
            sizeBytes: stat.size,
            createdAt: rFile.createdAt,
            isDownloaded: true,
          );

          await LocalDB.instance.upsertFile(updatedModel);
          filesDownloaded++;
          totalBytesTransferred += stat.size;
        }
      }

      // 5. Push any local files that the remote peer doesn't have
      final remoteFileIds = {for (var f in remoteFiles) f.id};
      final filesToUpload =
          localFiles.where((f) => !remoteFileIds.contains(f.id)).toList();

      int uploadCount = filesToUpload.length;
      int uploadedProcessed = 0;

      for (final lFile in filesToUpload) {
        final localDisk = File(lFile.localPath);
        if (!await localDisk.exists()) continue;

        uploadedProcessed++;
        _syncMessage =
            'Uploading ($uploadedProcessed/$uploadCount) ${lFile.name}...';
        _progress = 0.75 + (0.20 * (uploadedProcessed / (uploadCount > 0 ? uploadCount : 1)));
        notifyListeners();

        try {
          final uploadUri = Uri.parse(
              'http://$peerIp:$port/api/v1/upload?folderId=${Uri.encodeComponent(lFile.folderId)}&fileName=${Uri.encodeComponent(lFile.name)}&fileId=${Uri.encodeComponent(lFile.id)}&mimeType=${Uri.encodeComponent(lFile.mimeType)}');
          final uploadReq = await client.postUrl(uploadUri);
          uploadReq.headers.contentLength = await localDisk.length();
          await uploadReq.addStream(localDisk.openRead());
          final uploadRes = await uploadReq.close();

          if (uploadRes.statusCode == HttpStatus.created ||
              uploadRes.statusCode == HttpStatus.ok) {
            filesUploaded++;
            totalBytesTransferred += await localDisk.length();
          }
        } catch (e) {
          debugPrint('[SyncService] Failed to upload ${lFile.name}: $e');
        }
      }

      _lastSyncTime = DateTime.now();
      _pendingChanges = 0;
      _status = SyncStatus.synced;
      _progress = 1.0;

      final summary =
          'Synced: $foldersSynced folders, $filesDownloaded files received, $filesUploaded pushed (${(totalBytesTransferred / (1024 * 1024)).toStringAsFixed(1)} MB)';
      _syncMessage = summary;
      notifyListeners();

      return SyncStats(
        foldersSynced: foldersSynced,
        filesDownloaded: filesDownloaded,
        filesUploaded: filesUploaded,
        totalBytesTransferred: totalBytesTransferred,
        summary: summary,
      );
    } catch (e) {
      _status = SyncStatus.error;
      _syncMessage = 'Sync failed: $e';
      notifyListeners();
      rethrow;
    } finally {
      client.close();
    }
  }

  // ==========================================
  // REAL VAULT EXPORT & IMPORT (.finderly)
  // ==========================================

  /// Exports all folders, files, and metadata into a single .finderly package
  Future<File> exportVault() async {
    _status = SyncStatus.syncing;
    _syncMessage = 'Packaging Finderly vault...';
    _progress = 0.1;
    notifyListeners();

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final exportPath = p.join(tempDir.path, 'Finderly_Vault_$timestamp.finderly');
    final exportFile = File(exportPath);
    final raf = await exportFile.open(mode: FileMode.write);

    try {
      final folders = await LocalDB.instance.getAllFolders();
      final files = await LocalDB.instance.getAllFiles();

      final manifestMap = {
        'version': 1,
        'app': 'Finderly',
        'exportedAt': DateTime.now().toIso8601String(),
        'deviceName': _deviceName,
        'folders': folders.map((f) => f.toMap()).toList(),
        'files': files.map((f) => f.toMap()).toList(),
      };

      final manifestBytes = utf8.encode(jsonEncode(manifestMap));

      // Header: MAGIC (4) + VERSION (4) + MANIFEST_LEN (4)
      final header = ByteData(12);
      header.setUint8(0, 0x46); // 'F'
      header.setUint8(1, 0x4E); // 'N'
      header.setUint8(2, 0x44); // 'D'
      header.setUint8(3, 0x52); // 'R'
      header.setUint32(4, 1, Endian.big); // Version 1
      header.setUint32(8, manifestBytes.length, Endian.big);

      await raf.writeFrom(header.buffer.asUint8List());
      await raf.writeFrom(manifestBytes);

      // Write each file: ID_LEN (4) + ID (UTF8) + FILE_LEN (8) + BYTES
      int count = 0;
      for (final f in files) {
        count++;
        _progress = 0.2 + (0.75 * (count / (files.isNotEmpty ? files.length : 1)));
        _syncMessage = 'Packing file ($count/${files.length}) ${f.name}...';
        notifyListeners();

        final fileOnDisk = File(f.localPath);
        final fileExists = await fileOnDisk.exists();
        final fileLen = fileExists ? await fileOnDisk.length() : 0;

        final idBytes = utf8.encode(f.id);
        final fileHeader = ByteData(12);
        fileHeader.setUint32(0, idBytes.length, Endian.big);
        fileHeader.setUint64(4, fileLen, Endian.big);

        await raf.writeFrom(fileHeader.buffer.asUint8List());
        await raf.writeFrom(idBytes);

        if (fileExists && fileLen > 0) {
          final stream = fileOnDisk.openRead();
          await for (final chunk in stream) {
            await raf.writeFrom(chunk);
          }
        }
      }

      await raf.close();

      _status = SyncStatus.synced;
      _progress = 1.0;
      _syncMessage = 'Vault export complete: ${files.length} files included';
      notifyListeners();

      return exportFile;
    } catch (e) {
      await raf.close();
      _status = SyncStatus.error;
      _syncMessage = 'Export failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Imports and merges an external .finderly package into local database and storage
  Future<SyncStats> importVault(String filePath) async {
    _status = SyncStatus.syncing;
    _syncMessage = 'Opening Finderly vault archive...';
    _progress = 0.1;
    notifyListeners();

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Vault file does not exist at $filePath');
    }

    final raf = await file.open(mode: FileMode.read);
    final appStorageDir = await FileService().getAppStorageDir();

    try {
      // 1. Read header
      final headerBytes = await raf.read(12);
      if (headerBytes.length < 12) {
        throw Exception('Invalid Finderly vault: File is corrupted or too short');
      }

      final header = ByteData.sublistView(headerBytes);
      final magic = String.fromCharCodes(headerBytes.sublist(0, 4));
      if (magic != 'FNDR') {
        throw Exception('Invalid Finderly vault header: Expected FNDR');
      }

      final manifestLen = header.getUint32(8, Endian.big);
      final manifestBytes = await raf.read(manifestLen);
      final manifestStr = utf8.decode(manifestBytes);
      final manifestMap = jsonDecode(manifestStr) as Map<String, dynamic>;

      final foldersRaw = manifestMap['folders'] as List? ?? [];
      final filesRaw = manifestMap['files'] as List? ?? [];

      int foldersRestored = 0;
      for (final fMap in foldersRaw) {
        final folder = FolderModel.fromMap(fMap);
        await LocalDB.instance.upsertFolder(folder);
        foldersRestored++;
      }

      final fileMetadataMap = <String, FileItemModel>{};
      for (final fMap in filesRaw) {
        final item = FileItemModel.fromMap(fMap);
        fileMetadataMap[item.id] = item;
      }

      int filesRestored = 0;
      int totalBytes = 0;
      int fileCount = fileMetadataMap.length;

      while (await raf.position() < await raf.length()) {
        final chunkHeaderBytes = await raf.read(12);
        if (chunkHeaderBytes.length < 12) break;

        final chunkHeader = ByteData.sublistView(chunkHeaderBytes);
        final idLen = chunkHeader.getUint32(0, Endian.big);
        final fileLen = chunkHeader.getUint64(4, Endian.big);

        final idBytes = await raf.read(idLen);
        final fileId = utf8.decode(idBytes);

        final meta = fileMetadataMap[fileId];
        if (meta != null && fileLen > 0) {
          final folderDir = Directory(p.join(appStorageDir, meta.folderId));
          if (!await folderDir.exists()) {
            await folderDir.create(recursive: true);
          }

          final destPath = p.join(folderDir.path, meta.name);
          final outSink = File(destPath).openWrite();

          int remaining = fileLen;
          while (remaining > 0) {
            final toRead = remaining > 65536 ? 65536 : remaining;
            final dataChunk = await raf.read(toRead);
            if (dataChunk.isEmpty) break;
            outSink.add(dataChunk);
            remaining -= dataChunk.length;
          }
          await outSink.close();

          final updatedModel = FileItemModel(
            id: meta.id,
            name: meta.name,
            folderId: meta.folderId,
            localPath: destPath,
            mimeType: meta.mimeType,
            sizeBytes: fileLen,
            createdAt: meta.createdAt,
            isDownloaded: true,
          );

          await LocalDB.instance.upsertFile(updatedModel);
          filesRestored++;
          totalBytes += fileLen;

          _progress = 0.2 + (0.75 * (filesRestored / (fileCount > 0 ? fileCount : 1)));
          _syncMessage = 'Restored file ($filesRestored/$fileCount) ${meta.name}';
          notifyListeners();
        } else if (fileLen > 0) {
          // Skip unmapped bytes
          await raf.setPosition(await raf.position() + fileLen);
        }
      }

      await raf.close();

      _status = SyncStatus.synced;
      _lastSyncTime = DateTime.now();
      _progress = 1.0;
      final summary =
          'Import complete: $foldersRestored folders & $filesRestored files merged (${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB)';
      _syncMessage = summary;
      notifyListeners();

      return SyncStats(
        foldersSynced: foldersRestored,
        filesDownloaded: filesRestored,
        totalBytesTransferred: totalBytes,
        summary: summary,
      );
    } catch (e) {
      await raf.close();
      _status = SyncStatus.error;
      _syncMessage = 'Import error: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ==========================================
  // WEBDAV / NEXTCLOUD REAL HTTP SYNC
  // ==========================================

  Future<SyncStats> syncWithWebDav({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    _status = SyncStatus.syncing;
    _syncMessage = 'Connecting to WebDAV server...';
    _progress = 0.1;
    notifyListeners();

    final client = HttpClient();
    final authHeader =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    String normalizedUrl = serverUrl.trim();
    if (!normalizedUrl.endsWith('/')) normalizedUrl += '/';
    final baseUri = Uri.parse(normalizedUrl);
    final finderlyUri = baseUri.resolve('Finderly/');

    int foldersSynced = 0;
    int filesTransferred = 0;

    try {
      // 1. Ensure Finderly collection exists on WebDAV
      final mkcolReq = await client.openUrl('MKCOL', finderlyUri);
      mkcolReq.headers.add('Authorization', authHeader);
      final mkcolRes = await mkcolReq.close();
      await mkcolRes.drain();

      // 2. Upload manifest.json
      _syncMessage = 'Uploading database manifest to WebDAV...';
      _progress = 0.3;
      notifyListeners();

      final folders = await LocalDB.instance.getAllFolders();
      final files = await LocalDB.instance.getAllFiles();

      final manifestBytes = utf8.encode(jsonEncode({
        'version': 1,
        'app': 'Finderly',
        'updatedAt': DateTime.now().toIso8601String(),
        'folders': folders.map((f) => f.toMap()).toList(),
        'files': files.map((f) => f.toMap()).toList(),
      }));

      final manifestPutUri = finderlyUri.resolve('manifest.json');
      final putReq = await client.putUrl(manifestPutUri);
      putReq.headers.add('Authorization', authHeader);
      putReq.headers.contentType = ContentType.json;
      putReq.headers.contentLength = manifestBytes.length;
      putReq.add(manifestBytes);
      final putRes = await putReq.close();
      await putRes.drain();

      // 3. Upload physical files to WebDAV /Finderly/<fileId>_<filename>
      int idx = 0;
      for (final f in files) {
        idx++;
        _progress = 0.3 + (0.65 * (idx / (files.isNotEmpty ? files.length : 1)));
        _syncMessage = 'Syncing to cloud ($idx/${files.length}) ${f.name}...';
        notifyListeners();

        final localFile = File(f.localPath);
        if (!await localFile.exists()) continue;

        final remoteFileUri = finderlyUri
            .resolve('${f.id}_${Uri.encodeComponent(f.name)}');
        final filePut = await client.putUrl(remoteFileUri);
        filePut.headers.add('Authorization', authHeader);
        filePut.headers.contentLength = await localFile.length();
        await filePut.addStream(localFile.openRead());
        final res = await filePut.close();
        await res.drain();
        filesTransferred++;
      }

      foldersSynced = folders.length;
      _lastSyncTime = DateTime.now();
      _status = SyncStatus.synced;
      _progress = 1.0;
      final summary =
          'WebDAV sync complete: $foldersSynced folders and $filesTransferred files synchronized';
      _syncMessage = summary;
      notifyListeners();

      return SyncStats(
        foldersSynced: foldersSynced,
        filesUploaded: filesTransferred,
        summary: summary,
      );
    } catch (e) {
      _status = SyncStatus.error;
      _syncMessage = 'WebDAV sync error: $e';
      notifyListeners();
      rethrow;
    } finally {
      client.close();
    }
  }

  // ==========================================
  // GENERAL SYNC ALL TRIGGER
  // ==========================================

  Future<void> syncAll() async {
    // If we have discovered peers, sync with the most recent peer
    final peers = discoveredPeers;
    if (peers.isNotEmpty) {
      final target = peers.first;
      await syncWithPeer(target.ip, port: target.port);
      return;
    }

    // Check if WebDAV is configured
    final webdavUrl = await LocalDB.instance.getSetting('webdav_url');
    final webdavUser = await LocalDB.instance.getSetting('webdav_user');
    final webdavPass = await LocalDB.instance.getSetting('webdav_pass');

    if (webdavUrl != null && webdavUrl.isNotEmpty) {
      await syncWithWebDav(
        serverUrl: webdavUrl,
        username: webdavUser ?? '',
        password: webdavPass ?? '',
      );
      return;
    }

    // Otherwise, ensure local server is alive and update stats
    _status = SyncStatus.serverRunning;
    _lastSyncTime = DateTime.now();
    _pendingChanges = 0;
    _syncMessage = 'Server active on $_localIp:$_port — Ready to pair with nearby devices';
    notifyListeners();
  }

  void markPending() {
    _pendingChanges++;
    notifyListeners();
  }
}
