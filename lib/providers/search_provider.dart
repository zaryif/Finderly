import 'package:flutter/foundation.dart';

import 'package:finderly/database/local_db.dart';
import 'package:finderly/models/file_item_model.dart';
import 'package:finderly/models/folder_model.dart';

class SearchProvider extends ChangeNotifier {
  final _db = LocalDB.instance;

  String _query = '';
  List<FolderModel> _folderResults = [];
  List<FileItemModel> _fileResults = [];
  bool _isSearching = false;

  String get query => _query;
  List<FolderModel> get folderResults => _folderResults;
  List<FileItemModel> get fileResults => _fileResults;
  bool get isSearching => _isSearching;

  Future<void> search(String query) async {
    _query = query;
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }
    _isSearching = true;
    notifyListeners();
    _folderResults = await _db.searchFolders(query);
    _fileResults = await _db.searchFiles(query);
    _isSearching = false;
    notifyListeners();
  }

  void clearSearch() {
    _query = '';
    _folderResults = [];
    _fileResults = [];
    _isSearching = false;
    notifyListeners();
  }
}
