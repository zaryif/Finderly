import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finderly/providers/search_provider.dart';
import 'package:finderly/widgets/folder_icon.dart';
import 'package:finderly/widgets/file_tile.dart';
import 'package:finderly/screens/folder_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<SearchProvider>().search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search folders and files...',
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                context.read<SearchProvider>().clearSearch();
              },
            ),
        ],
      ),
      body: Consumer<SearchProvider>(
        builder: (context, provider, _) {
          if (provider.query.isEmpty) {
            return const Center(
              child: Text(
                'Type to search',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          if (provider.folderResults.isEmpty && provider.fileResults.isEmpty) {
            return const Center(
              child: Text(
                'No results',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView(
            children: [
              if (provider.folderResults.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Folders',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ...provider.folderResults.map((folder) => ListTile(
                      leading: FolderIcon(color: folder.color, size: 36),
                      title: Text(folder.name),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FolderScreen(folder: folder),
                        ),
                      ),
                    )),
              ],
              if (provider.fileResults.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Files',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ...provider.fileResults.map((file) => FileTile(file: file)),
              ],
            ],
          );
        },
      ),
    );
  }
}
