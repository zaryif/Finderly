import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/providers/folder_provider.dart';
import 'package:finderly/widgets/folder_icon.dart';

class MoveDestinationResult {
  final FolderModel? targetFolder; // null = root / top level (only valid for folders)
  final bool isRoot;

  const MoveDestinationResult({this.targetFolder, this.isRoot = false});
}

class MoveDestinationDialog extends StatefulWidget {
  final List<String> excludeFolderIds;
  final String title;
  final bool allowRoot; // true when moving folders to top-level

  const MoveDestinationDialog({
    super.key,
    this.excludeFolderIds = const [],
    this.title = 'Move to Folder',
    this.allowRoot = true,
  });

  static Future<MoveDestinationResult?> show(
    BuildContext context, {
    List<String> excludeFolderIds = const [],
    String title = 'Move to Folder',
    bool allowRoot = true,
  }) {
    return showDialog<MoveDestinationResult>(
      context: context,
      builder: (_) => MoveDestinationDialog(
        excludeFolderIds: excludeFolderIds,
        title: title,
        allowRoot: allowRoot,
      ),
    );
  }

  @override
  State<MoveDestinationDialog> createState() => _MoveDestinationDialogState();
}

class _MoveDestinationDialogState extends State<MoveDestinationDialog> {
  List<FolderModel>? _candidates;
  String _searchQuery = '';
  FolderModel? _selectedFolder;
  bool _selectedRoot = false;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    final list = await context
        .read<FolderProvider>()
        .getMoveCandidates(excludeFolderIds: widget.excludeFolderIds);
    if (mounted) {
      setState(() {
        _candidates = list;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = (_candidates ?? []).where((f) {
      if (_searchQuery.isEmpty) return true;
      return f.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final canConfirm = _selectedRoot || _selectedFolder != null;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.drive_file_move_rounded, size: 24, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 360,
        height: 380,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Search destination folder...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _candidates == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        if (widget.allowRoot)
                          ListTile(
                            dense: true,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.home_outlined, color: Colors.blue, size: 20),
                            ),
                            title: const Text(
                              'Finderly Home (Top Level)',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            trailing: _selectedRoot
                                ? const Icon(Icons.check_circle, color: Colors.blue, size: 20)
                                : null,
                            selected: _selectedRoot,
                            selectedTileColor: Colors.blue.withOpacity(0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onTap: () {
                              setState(() {
                                _selectedRoot = true;
                                _selectedFolder = null;
                              });
                            },
                          ),
                        if (widget.allowRoot && filtered.isNotEmpty)
                          const Divider(height: 12),
                        if (filtered.isEmpty && (!widget.allowRoot || _searchQuery.isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'No other folders available'
                                    : 'No folders match "$_searchQuery"',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ...filtered.map((folder) {
                            final isSelected = !_selectedRoot && _selectedFolder?.id == folder.id;
                            return ListTile(
                              dense: true,
                              leading: FolderIcon(color: folder.color, size: 34),
                              title: Text(
                                folder.name,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: Colors.blue, size: 20)
                                  : null,
                              selected: isSelected,
                              selectedTileColor: Colors.blue.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              onTap: () {
                                setState(() {
                                  _selectedRoot = false;
                                  _selectedFolder = folder;
                                });
                              },
                            );
                          }),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.drive_file_move_outlined, size: 18),
          label: Text(
            _selectedRoot
                ? 'Move to Home'
                : (_selectedFolder != null ? 'Move Here' : 'Select Folder'),
          ),
          onPressed: canConfirm
              ? () {
                  Navigator.pop(
                    context,
                    MoveDestinationResult(
                      targetFolder: _selectedFolder,
                      isRoot: _selectedRoot,
                    ),
                  );
                }
              : null,
        ),
      ],
    );
  }
}

