import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:finderly/database/local_db.dart';

class GoogleUserProfile {
  final String email;
  final String displayName;
  final String? avatarUrl;

  GoogleUserProfile({
    required this.email,
    required this.displayName,
    this.avatarUrl,
  });
}

class GoogleDriveService extends ChangeNotifier {
  static final GoogleDriveService instance = GoogleDriveService._();
  GoogleDriveService._();

  // Default Finderly Google OAuth 2.0 Web/Desktop Client Credentials
  static const String defaultClientId =
      '379261748892-finderly-client.apps.googleusercontent.com';
  static const String defaultRedirectUri =
      'http://127.0.0.1:8765/oauth2callback';

  bool _isSignedIn = false;
  bool _isSyncing = false;
  String? _syncMessage;
  double _progress = 0.0;
  DateTime? _lastSyncTime;
  GoogleUserProfile? _profile;

  String? _accessToken;
  String? _refreshToken;
  String? _codeVerifier;
  String? _currentFolderDriveId;

  bool get isSignedIn => _isSignedIn;
  bool get isSyncing => _isSyncing;
  String? get syncMessage => _syncMessage;
  double get progress => _progress;
  DateTime? get lastSyncTime => _lastSyncTime;
  GoogleUserProfile? get profile => _profile;

  Future<void> initialize() async {
    final email = await LocalDB.instance.getSetting('google_email');
    final name = await LocalDB.instance.getSetting('google_name');
    final avatar = await LocalDB.instance.getSetting('google_avatar');
    final token = await LocalDB.instance.getSetting('google_access_token');
    final refresh = await LocalDB.instance.getSetting('google_refresh_token');
    final lastSyncStr = await LocalDB.instance.getSetting('google_last_sync');

    if (email != null && token != null) {
      _isSignedIn = true;
      _accessToken = token;
      _refreshToken = refresh;
      _profile = GoogleUserProfile(
        email: email,
        displayName: name ?? email.split('@').first,
        avatarUrl: avatar,
      );
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.tryParse(lastSyncStr);
      }
      notifyListeners();
    }
  }

  // ==========================================
  // OAUTH 2.0 SIGN IN WITH GOOGLE
  // ==========================================

  String _generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Initiates OAuth 2.0 PKCE flow in browser
  Future<void> signInWithGoogle({String? customClientId}) async {
    final clientId = (customClientId != null && customClientId.isNotEmpty)
        ? customClientId
        : defaultClientId;

    _codeVerifier = _generateRandomString(64);
    final challengeBytes = sha256.convert(ascii.encode(_codeVerifier!)).bytes;
    final codeChallenge = base64UrlEncode(challengeBytes).replaceAll('=', '');

    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': defaultRedirectUri,
      'response_type': 'code',
      'scope':
          'https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'consent',
    });

    if (await canLaunchUrl(authUri)) {
      await launchUrl(authUri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not open system browser for Google sign-in.');
    }
  }

  /// Handles incoming authorization code from redirect
  Future<void> handleAuthCode(String code, {String? customClientId, String? clientSecret}) async {
    final clientId = (customClientId != null && customClientId.isNotEmpty)
        ? customClientId
        : defaultClientId;

    final bodyFields = {
      'code': code,
      'client_id': clientId,
      'redirect_uri': defaultRedirectUri,
      'grant_type': 'authorization_code',
      if (_codeVerifier != null) 'code_verifier': _codeVerifier!,
      if (clientSecret != null) 'client_secret': clientSecret,
    };

    final client = HttpClient();
    try {
      final tokenUri = Uri.parse('https://oauth2.googleapis.com/token');
      final req = await client.postUrl(tokenUri);
      req.headers.contentType = ContentType.parse('application/x-www-form-urlencoded');
      final encodedBody = bodyFields.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      req.write(encodedBody);

      final res = await req.close();
      final resBody = await res.transform(utf8.decoder).join();
      final data = jsonDecode(resBody) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        throw Exception('${data['error']}: ${data['error_description']}');
      }

      _accessToken = data['access_token'] as String?;
      _refreshToken = data['refresh_token'] as String?;

      if (_accessToken != null) {
        await LocalDB.instance.setSetting('google_access_token', _accessToken!);
        if (_refreshToken != null) {
          await LocalDB.instance.setSetting('google_refresh_token', _refreshToken!);
        }

        await _fetchUserProfile();
        _isSignedIn = true;
        notifyListeners();
      }
    } finally {
      client.close();
    }
  }

  /// Manually authenticate with an Access Token
  Future<void> setDirectAccessToken(String token, {String? refreshToken}) async {
    _accessToken = token.trim();
    if (refreshToken != null) _refreshToken = refreshToken.trim();

    await LocalDB.instance.setSetting('google_access_token', _accessToken!);
    if (_refreshToken != null) {
      await LocalDB.instance.setSetting('google_refresh_token', _refreshToken!);
    }

    await _fetchUserProfile();
    _isSignedIn = true;
    notifyListeners();
  }

  Future<void> _fetchUserProfile() async {
    if (_accessToken == null) return;
    final client = HttpClient();
    try {
      final uri = Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo');
      final req = await client.getUrl(uri);
      req.headers.add('Authorization', 'Bearer $_accessToken');
      final res = await req.close();
      if (res.statusCode == HttpStatus.ok) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;

        final email = (data['email'] as String?) ?? 'Google User';
        final name = (data['name'] as String?) ?? email.split('@').first;
        final avatar = data['picture'] as String?;

        _profile = GoogleUserProfile(
          email: email,
          displayName: name,
          avatarUrl: avatar,
        );

        await LocalDB.instance.setSetting('google_email', email);
        await LocalDB.instance.setSetting('google_name', name);
        if (avatar != null) {
          await LocalDB.instance.setSetting('google_avatar', avatar);
        }
      }
    } catch (e) {
      debugPrint('[GoogleDriveService] UserInfo fetch error: $e');
    } finally {
      client.close();
    }
  }

  Future<void> signOut() async {
    _isSignedIn = false;
    _accessToken = null;
    _refreshToken = null;
    _profile = null;
    _lastSyncTime = null;

    await LocalDB.instance.setSetting('google_access_token', '');
    await LocalDB.instance.setSetting('google_refresh_token', '');
    await LocalDB.instance.setSetting('google_email', '');
    await LocalDB.instance.setSetting('google_name', '');
    await LocalDB.instance.setSetting('google_avatar', '');
    notifyListeners();
  }

  // ==========================================
  // REAL GOOGLE DRIVE SYNC ENGINE
  // ==========================================

  Future<String> _getOrCreateFinderlyFolder(HttpClient client) async {
    if (_currentFolderDriveId != null) return _currentFolderDriveId!;

    final savedId = await LocalDB.instance.getSetting('google_folder_id');
    if (savedId != null && savedId.isNotEmpty) {
      _currentFolderDriveId = savedId;
      return savedId;
    }

    // 1. Search for existing Finderly folder
    final query = Uri.encodeQueryComponent(
        "name = 'Finderly' and mimeType = 'application/vnd.google-apps.folder' and trashed = false");
    final searchUri =
        Uri.parse('https://www.googleapis.com/drive/v3/files?q=$query&fields=files(id,name)');

    final searchReq = await client.getUrl(searchUri);
    searchReq.headers.add('Authorization', 'Bearer $_accessToken');
    final searchRes = await searchReq.close();

    if (searchRes.statusCode == HttpStatus.ok) {
      final body = await searchRes.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final files = data['files'] as List? ?? [];
      if (files.isNotEmpty) {
        final folderId = files.first['id'] as String;
        _currentFolderDriveId = folderId;
        await LocalDB.instance.setSetting('google_folder_id', folderId);
        return folderId;
      }
    }

    // 2. Create Finderly folder in root
    final createUri = Uri.parse('https://www.googleapis.com/drive/v3/files');
    final createReq = await client.postUrl(createUri);
    createReq.headers.add('Authorization', 'Bearer $_accessToken');
    createReq.headers.contentType = ContentType.json;
    createReq.write(jsonEncode({
      'name': 'Finderly',
      'mimeType': 'application/vnd.google-apps.folder',
      'description': 'Finderly cross-platform vault sync folder',
    }));

    final createRes = await createReq.close();
    final createBody = await createRes.transform(utf8.decoder).join();
    final createdData = jsonDecode(createBody) as Map<String, dynamic>;
    final folderId = createdData['id'] as String;

    _currentFolderDriveId = folderId;
    await LocalDB.instance.setSetting('google_folder_id', folderId);
    return folderId;
  }

  /// Syncs local files and folders with Google Drive
  Future<String> syncNow() async {
    if (!_isSignedIn || _accessToken == null) {
      throw Exception('Not signed in to Google. Please sign in first.');
    }
    if (_isSyncing) return 'Sync already in progress';

    _isSyncing = true;
    _progress = 0.05;
    _syncMessage = 'Connecting to Google Drive...';
    notifyListeners();

    final client = HttpClient();
    int foldersSynced = 0;
    int filesUploaded = 0;

    try {
      final driveFolderId = await _getOrCreateFinderlyFolder(client);

      // 1. Upload manifest.json to Google Drive
      _syncMessage = 'Uploading vault index to Google Drive...';
      _progress = 0.2;
      notifyListeners();

      final folders = await LocalDB.instance.getAllFolders();
      final files = await LocalDB.instance.getAllFiles();

      final manifestData = {
        'version': 1,
        'app': 'Finderly',
        'exportedAt': DateTime.now().toIso8601String(),
        'folders': folders.map((f) => f.toMap()).toList(),
        'files': files.map((f) => f.toMap()).toList(),
      };
      final manifestJson = jsonEncode(manifestData);

      await _uploadMultipartFile(
        client: client,
        fileName: 'manifest.json',
        mimeType: 'application/json',
        dataBytes: utf8.encode(manifestJson),
        parentFolderId: driveFolderId,
      );
      foldersSynced = folders.length;

      // 2. Upload local physical files to Google Drive
      int count = 0;
      for (final f in files) {
        count++;
        _progress = 0.2 + (0.7 * (count / (files.isNotEmpty ? files.length : 1)));
        _syncMessage = 'Syncing to Google Drive ($count/${files.length}) ${f.name}...';
        notifyListeners();

        final localFile = File(f.localPath);
        if (!await localFile.exists()) continue;

        final fileBytes = await localFile.readAsBytes();
        await _uploadMultipartFile(
          client: client,
          fileName: '${f.id}_${f.name}',
          mimeType: f.mimeType,
          dataBytes: fileBytes,
          parentFolderId: driveFolderId,
        );
        filesUploaded++;
      }

      _lastSyncTime = DateTime.now();
      await LocalDB.instance
          .setSetting('google_last_sync', _lastSyncTime!.toIso8601String());

      _progress = 1.0;
      _isSyncing = false;
      final summary =
          'Google Drive synced: $foldersSynced folders & $filesUploaded files uploaded';
      _syncMessage = summary;
      notifyListeners();
      return summary;
    } catch (e) {
      _isSyncing = false;
      _syncMessage = 'Google Drive error: $e';
      notifyListeners();
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> _uploadMultipartFile({
    required HttpClient client,
    required String fileName,
    required String mimeType,
    required List<int> dataBytes,
    required String parentFolderId,
  }) async {
    const boundary = '-------FinderlyDriveBoundary';
    final uploadUri = Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart');

    final req = await client.postUrl(uploadUri);
    req.headers.add('Authorization', 'Bearer $_accessToken');
    req.headers.contentType = ContentType.parse('multipart/related; boundary=$boundary');

    final metadata = {
      'name': fileName,
      'parents': [parentFolderId],
    };

    final body = BytesBuilder();
    body.add(utf8.encode('--$boundary\r\n'));
    body.add(utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'));
    body.add(utf8.encode(jsonEncode(metadata)));
    body.add(utf8.encode('\r\n'));

    body.add(utf8.encode('--$boundary\r\n'));
    body.add(utf8.encode('Content-Type: $mimeType\r\n\r\n'));
    body.add(dataBytes);
    body.add(utf8.encode('\r\n'));

    body.add(utf8.encode('--$boundary--\r\n'));

    final payload = body.toBytes();
    req.headers.contentLength = payload.length;
    req.add(payload);

    final res = await req.close();
    await res.drain();
  }
}

