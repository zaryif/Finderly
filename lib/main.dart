import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:finderly/providers/folder_provider.dart';
import 'package:finderly/providers/file_provider.dart';
import 'package:finderly/providers/search_provider.dart';
import 'package:finderly/database/local_db.dart';
import 'package:finderly/services/sync_service.dart';
import 'package:finderly/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for macOS, Windows & Linux desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    await LocalDB.instance.database;
  } catch (e) {
    debugPrint('Database init warning: $e');
  }

  // Initialize background real-time sync service & peer discovery
  try {
    SyncService.instance.initialize().catchError((e) {
      debugPrint('Sync initialization warning: $e');
    });
  } catch (e) {
    debugPrint('Sync service startup warning: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FolderProvider()),
        ChangeNotifierProvider(create: (_) => FileProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
      ],
      child: const FinderlyApp(),
    ),
  );
}
