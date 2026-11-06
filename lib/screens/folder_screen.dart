import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/models/file_item_model.dart';
import 'package:finderly/providers/folder_provider.dart';
import 'package:finderly/providers/file_provider.dart';
import 'package:finderly/providers/background_provider.dart';
import 'package:finderly/widgets/folder_card.dart';
import 'package:finderly/widgets/folder_icon.dart';
import 'package:finderly/widgets/file_tile.dart';
import 'package:finderly/widgets/color_picker_dialog.dart';
import 'package:finderly/widgets/merge_folder_dialog.dart';
import 'package:finderly/widgets/move_destination_dialog.dart';
import 'package:finderly/theme/folder_colors.dart';

class FolderScreen extends StatefulWidget {
  final FolderModel folder;

  const FolderScreen({super.key, required this.folder});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  late FolderModel _currentFolder;

  // Multi-selection state
  bool _isSelecting = false;
  final Set<String> _selectedFolderIds = {};
  final Set<String> _selectedFileIds = {};

  @override
  void initState() {
    super.initState();
    _currentFolder = widget.folder;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  void _refresh() {
    context.read<FileProvider>().loadFiles(_currentFolder.id);
    context.read<FolderProvider>().loadFolders(_currentFolder.id);
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelecting = false;
      _selectedFolderIds.clear();
      _selectedFileIds.clear();
    });
  }

  void _toggleFolderSelection(String folderId) {
    setState(() {
      if (!_isSelecting) _isSelecting = true;
      if (_selectedFolderIds.contains(folderId)) {
        _selectedFolderIds.remove(folderId);
        if (_selectedFolderIds.isEmpty && _selectedFileIds.isEmpty) {
          _isSelecting = false;
        }
      } else {
        _selectedFolderIds.add(folderId);
      }
    });
  }

  void _toggleFileSelection(String fileId) {
    setState(() {
      if (!_isSelecting) _isSelecting = true;
      if (_selectedFileIds.contains(fileId)) {
        _selectedFileIds.remove(fileId);
        if (_selectedFolderIds.isEmpty && _selectedFileIds.isEmpty) {
          _isSelecting = false;
        }
      } else {
        _selectedFileIds.add(fileId);
      }
    });
  }

  void _selectAll(List<FolderModel> subfolders, List<FileItemModel> files) {
    setState(() {
      final totalItems = subfolders.length + files.length;
      final currentSelected = _selectedFolderIds.length + _selectedFileIds.length;
      if (currentSelected == totalItems) {
        // Deselect all
        _selectedFolderIds.clear();
        _selectedFileIds.clear();
        _isSelecting = false;
      } else {
        _isSelecting = true;
        _selectedFolderIds.addAll(subfolders.map((f) => f.id));
        _selectedFileIds.addAll(files.map((f) => f.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgProvider = context.watch<BackgroundProvider>();
    final currentBg = bgProvider.current;
    final iconColor = currentBg.iconColor;
    final textColor = currentBg.textColor;

    final folderProvider = context.watch<FolderProvider>();
    final fileProvider = context.watch<FileProvider>();

    final subfolders = folderProvider.folders;
    final files = fileProvider.files;

    final selectedCount = _selectedFolderIds.length + _selectedFileIds.length;
    final isAllSelected = (subfolders.length + files.length > 0) &&
        (selectedCount == subfolders.length + files.length);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: currentBg.solidColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: iconColor),
        leading: _isSelecting
            ? IconButton(
                icon: Icon(Icons.close, color: iconColor),
                tooltip: 'Cancel selection',
                onPressed: _exitSelectionMode,
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, color: iconColor),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSelecting
            ? Text(
                '$selectedCount selected',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: textColor,
                ),
              )
            : Row(
                children: [
                  FolderIcon(color: _currentFolder.color, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentFolder.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
        actions: _isSelecting
            ? [
                TextButton(
                  onPressed: () => _selectAll(subfolders, files),
                  child: Text(
                    isAllSelected ? 'Deselect All' : 'Select All',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.checklist_rtl_rounded, size: 24, color: iconColor),
                  tooltip: 'Select items',
                  onPressed: (subfolders.isEmpty && files.isEmpty)
                      ? null
                      : () => setState(() => _isSelecting = true),
                ),
                IconButton(
                  icon: Icon(Icons.add, size: 26, color: iconColor),
                  tooltip: 'Add',
                  onPressed: _showAddOptions,
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: iconColor),
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: iconColor),
                  onSelected: _handleMenuAction,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'move',
                      child: Row(
                        children: [
                          Icon(Icons.drive_file_move_outlined, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Move folder into...'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(value: 'rename', child: Text('Rename folder')),
                    const PopupMenuItem(value: 'color', child: Text('Change color')),
                    const PopupMenuItem(value: 'merge', child: Text('Merge folder into...')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete folder', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: currentBg.decoration,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SubfoldersSection(
                parentId: _currentFolder.id,
                isSelecting: _isSelecting,
                selectedFolderIds: _selectedFolderIds,
                onSelectToggle: _toggleFolderSelection,
                onSubfolderPopped: _refresh,
                onMoveFolder: _moveSingleFolder,
              ),
              if (subfolders.isNotEmpty)
                Divider(height: 1, color: currentBg.borderColor),
              Expanded(
                child: _FilesSection(
                  folderId: _currentFolder.id,
                  isSelecting: _isSelecting,
                  selectedFileIds: _selectedFileIds,
                  onSelectToggle: _toggleFileSelection,
                  onFileRenamed: (file) => _renameFileDialog(context, file),
                  onMoveFile: _moveSingleFile,
                ),
              ),
              if (_isSelecting)
                _buildSelectionActionBar(context, currentBg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionActionBar(BuildContext context, AppBackground currentBg) {
    final selectedCount = _selectedFolderIds.length + _selectedFileIds.length;
    final hasSelection = selectedCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: currentBg.cardColor,
        border: Border(top: BorderSide(color: currentBg.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.drive_file_move_outlined, size: 20),
                label: Text(
                  'Move ($selectedCount)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onPressed: hasSelection ? _moveSelectedItems : null,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.delete_outline, size: 20),
              label: const Text('Delete'),
              onPressed: hasSelection ? _deleteSelectedItems : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveSelectedItems() async {
    final allowRoot = _selectedFileIds.isEmpty; // files must be in a folder, folders can go to root
    final fileProvider = context.read<FileProvider>();
    final folderProvider = context.read<FolderProvider>();

    final result = await MoveDestinationDialog.show(
      context,
      excludeFolderIds: _selectedFolderIds.toList(),
      title: 'Move ${_selectedFolderIds.length + _selectedFileIds.length} items to...',
      allowRoot: allowRoot,
    );

    if (result == null || !mounted) return;

    final targetFolder = result.targetFolder;
    final isRoot = result.isRoot;

    if (isRoot && _selectedFileIds.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Files must be placed inside a folder. Please select a folder destination.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final targetId = targetFolder?.id;
    final targetName = isRoot ? 'Finderly Home' : (targetFolder?.name ?? 'Selected folder');

    // 1. Move files
    if (_selectedFileIds.isNotEmpty && targetId != null) {
      await fileProvider.moveFiles(
        _selectedFileIds.toList(),
        targetId,
        currentFolderId: _currentFolder.id,
      );
    }

    if (!mounted) return;

    // 2. Move subfolders
    if (_selectedFolderIds.isNotEmpty) {
      await folderProvider.moveFolders(
        _selectedFolderIds.toList(),
        targetId,
        refreshParentId: _currentFolder.id,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved items into "$targetName"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _exitSelectionMode();
      _refresh();
    }
  }

  Future<void> _deleteSelectedItems() async {
    final fileProvider = context.read<FileProvider>();
    final folderProvider = context.read<FolderProvider>();
    final count = _selectedFolderIds.length + _selectedFileIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Items?'),
        content: Text('Permanently delete $count selected item(s)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    for (final fId in _selectedFileIds) {
      await fileProvider.deleteFile(fId);
    }

    for (final folId in _selectedFolderIds) {
      await folderProvider.deleteFolder(folId);
    }

    if (mounted) {
      _exitSelectionMode();
      _refresh();
    }
  }

  Future<void> _moveSingleFile(FileItemModel file) async {
    final fileProvider = context.read<FileProvider>();
    final result = await MoveDestinationDialog.show(
      context,
      excludeFolderIds: const [],
      title: 'Move "${file.name}" to...',
      allowRoot: false,
    );

    if (result != null && result.targetFolder != null && mounted) {
      await fileProvider.moveFiles(
        [file.id],
        result.targetFolder!.id,
        currentFolderId: _currentFolder.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved "${file.name}" to "${result.targetFolder!.name}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refresh();
      }
    }
  }

  Future<void> _moveSingleFolder(FolderModel folder) async {
    final folderProvider = context.read<FolderProvider>();
    final result = await MoveDestinationDialog.show(
      context,
      excludeFolderIds: [folder.id],
      title: 'Move "${folder.name}" to...',
      allowRoot: true,
    );

    if (result != null && mounted) {
      final targetParentId = result.isRoot ? null : result.targetFolder?.id;
      final destName = result.isRoot ? 'Finderly Home' : result.targetFolder?.name;
      await folderProvider.moveFolders(
        [folder.id],
        targetParentId,
        refreshParentId: _currentFolder.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved "${folder.name}" to "$destName"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _refresh();
      }
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Import Files'),
              subtitle: const Text('Select one or more files (PDF, images, etc.)'),
              onTap: () {
                Navigator.pop(context);
                context.read<FileProvider>().importFiles(_currentFolder.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder, color: Colors.amber),
              title: const Text('New Subfolder'),
              subtitle: const Text('Create a colored nested folder'),
              onTap: () {
                Navigator.pop(context);
                _createSubfolder();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSubfolder() async {
    final controller = TextEditingController();
    var selectedColor = FolderColor.blue;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New Subfolder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Folder name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Color: '),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      final color = await ColorPickerDialog.show(
                        ctx,
                        current: selectedColor,
                      );
                      if (color != null) setState(() => selectedColor = color);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selectedColor.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty && mounted) {
      await context.read<FolderProvider>().createFolder(
            controller.text.trim(),
            selectedColor,
            _currentFolder.id,
          );
      _refresh();
    }
    controller.dispose();
  }

  Future<void> _handleMenuAction(String action) async {
    final folderProvider = context.read<FolderProvider>();
    switch (action) {
      case 'move':
        _moveCurrentFolder();
      case 'rename':
        final controller = TextEditingController(text: _currentFolder.name);
        final name = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Rename Folder'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Rename'),
              ),
            ],
          ),
        );
        if (name != null && name.trim().isNotEmpty) {
          final trimmed = name.trim();
          await folderProvider.renameFolder(_currentFolder.id, trimmed);
          setState(() {
            _currentFolder = _currentFolder.copyWith(name: trimmed);
          });
        }
        controller.dispose();
      case 'color':
        final color = await ColorPickerDialog.show(context, current: _currentFolder.color);
        if (color != null) {
          await folderProvider.changeFolderColor(_currentFolder.id, color);
          setState(() {
            _currentFolder = _currentFolder.copyWith(color: color);
          });
        }
      case 'merge':
        final target = await MergeFolderDialog.show(context, _currentFolder);
        if (target != null && mounted) {
          await folderProvider.mergeFolders(
            _currentFolder.id,
            target.id,
            refreshParentId: _currentFolder.parentId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Merged "${_currentFolder.name}" into "${target.name}"'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context);
          }
        }
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Folder?'),
            content: Text('Delete "${_currentFolder.name}" and all its contents?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) {
          await folderProvider.deleteFolder(_currentFolder.id);
          if (mounted) Navigator.pop(context);
        }
    }
  }

  Future<void> _moveCurrentFolder() async {
    final folderProvider = context.read<FolderProvider>();
    final result = await MoveDestinationDialog.show(
      context,
      excludeFolderIds: [_currentFolder.id],
      title: 'Move "${_currentFolder.name}" to...',
      allowRoot: true,
    );

    if (result != null && mounted) {
      final targetParentId = result.isRoot ? null : result.targetFolder?.id;
      final destName = result.isRoot ? 'Finderly Home' : result.targetFolder?.name;
      await folderProvider.moveFolders(
        [_currentFolder.id],
        targetParentId,
        refreshParentId: _currentFolder.parentId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved "${_currentFolder.name}" to "$destName"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _renameFileDialog(BuildContext context, FileItemModel file) async {
    final controller = TextEditingController(text: file.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && context.mounted) {
      await context.read<FileProvider>().renameFile(file.id, newName);
    }
    controller.dispose();
  }
}

class _SubfoldersSection extends StatelessWidget {
  final String parentId;
  final bool isSelecting;
  final Set<String> selectedFolderIds;
  final Function(String) onSelectToggle;
  final VoidCallback onSubfolderPopped;
  final Function(FolderModel) onMoveFolder;

  const _SubfoldersSection({
    required this.parentId,
    required this.isSelecting,
    required this.selectedFolderIds,
    required this.onSelectToggle,
    required this.onSubfolderPopped,
    required this.onMoveFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FolderProvider>(
      builder: (context, provider, _) {
        final subfolders = provider.folders;
        if (subfolders.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Subfolders (${subfolders.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: subfolders.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  final folder = subfolders[index];
                  final isSelected = selectedFolderIds.contains(folder.id);

                  return SizedBox(
                    width: 96,
                    child: FolderCard(
                      folder: folder,
                      isSelecting: isSelecting,
                      isSelected: isSelected,
                      onSelectToggle: () => onSelectToggle(folder.id),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FolderScreen(folder: folder),
                          ),
                        ).then((_) => onSubfolderPopped());
                      },
                      onRename: () => _renameSubfolder(context, folder),
                      onChangeColor: () => _changeSubfolderColor(context, folder),
                      onMove: () => onMoveFolder(folder),
                      onMerge: () => _mergeSubfolder(context, folder),
                      onDelete: () => _deleteSubfolder(context, folder),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameSubfolder(BuildContext context, FolderModel folder) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Subfolder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Rename')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty && context.mounted) {
      await context.read<FolderProvider>().renameFolder(folder.id, name.trim());
      onSubfolderPopped();
    }
  }

  Future<void> _changeSubfolderColor(BuildContext context, FolderModel folder) async {
    final color = await ColorPickerDialog.show(context, current: folder.color);
    if (color != null && context.mounted) {
      await context.read<FolderProvider>().changeFolderColor(folder.id, color);
      onSubfolderPopped();
    }
  }

  Future<void> _mergeSubfolder(BuildContext context, FolderModel folder) async {
    final target = await MergeFolderDialog.show(context, folder);
    if (target != null && context.mounted) {
      await context.read<FolderProvider>().mergeFolders(
        folder.id,
        target.id,
        refreshParentId: parentId,
      );
      onSubfolderPopped();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merged "${folder.name}" into "${target.name}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteSubfolder(BuildContext context, FolderModel folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subfolder?'),
        content: Text('Delete "${folder.name}" and all its contents?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<FolderProvider>().deleteFolder(folder.id);
      onSubfolderPopped();
    }
  }
}

class _FilesSection extends StatelessWidget {
  final String folderId;
  final bool isSelecting;
  final Set<String> selectedFileIds;
  final Function(String) onSelectToggle;
  final Function(FileItemModel) onFileRenamed;
  final Function(FileItemModel) onMoveFile;

  const _FilesSection({
    required this.folderId,
    required this.isSelecting,
    required this.selectedFileIds,
    required this.onSelectToggle,
    required this.onFileRenamed,
    required this.onMoveFile,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FileProvider>(
      builder: (context, provider, _) {
        final files = provider.files;

        if (files.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_outlined, size: 54, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text('No files in this folder yet', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                const Text('Tap + at top to import PDF, image, or any file', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final isSelected = selectedFileIds.contains(file.id);

            return FileTile(
              file: file,
              isSelecting: isSelecting,
              isSelected: isSelected,
              onSelectToggle: () => onSelectToggle(file.id),
              onRename: () => onFileRenamed(file),
              onMove: () => onMoveFile(file),
              onDelete: () => provider.deleteFile(file.id),
              onDownloadToggle: () => provider.toggleDownload(file.id),
            );
          },
        );
      },
    );
  }
}
