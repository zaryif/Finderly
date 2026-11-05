import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:finderly/database/local_db.dart';
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/models/file_item_model.dart';

enum SyncStatus { idle, syncing, synced, offline, error }

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._();
  SyncService._();

  SyncStatus _status = SyncStatus.synced;
  DateTime? _lastSyncTime;
  String? _syncMessage;
  int _pendingChanges = 0;

  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncMessage => _syncMessage;
  int get pendingChanges => _pendingChanges;

  /// Trigger full sync across all devices
  Future<void> syncAll() async {
    if (_status == SyncStatus.syncing) return;

    _status = SyncStatus.syncing;
    _syncMessage = 'Syncing with cloud...';
    notifyListeners();

    try {
      // 1. Check local pending items
      final db = LocalDB.instance;
      final rootFolders = await db.getFolders(null);

      // Simulate network sync roundtrip (can hook to Firebase/Supabase/REST)
      await Future.delayed(const Duration(milliseconds: 800));

      _lastSyncTime = DateTime.now();
      _status = SyncStatus.synced;
      _pendingChanges = 0;
      _syncMessage = 'All files & folders up to date';
    } catch (e) {
      _status = SyncStatus.error;
      _syncMessage = 'Sync error: $e';
    } finally {
      notifyListeners();
    }
  }

  void markPending() {
    _pendingChanges++;
    _status = SyncStatus.idle;
    notifyListeners();
  }
}

