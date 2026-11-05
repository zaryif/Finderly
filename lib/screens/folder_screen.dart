import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/models/file_item_model.dart';
import 'package:finderly/providers/folder_provider.dart';
import 'package:finderly/providers/file_provider.dart';
import 'package:finderly/widgets/folder_card.dart';
import 'package:finderly/widgets/folder_icon.dart';
import 'package:finderly/widgets/file_tile.dart';
import 'package:finderly/widgets/color_picker_dialog.dart';
import 'package:finderly/theme/folder_colors.dart';

class FolderScreen extends StatefulWidget {
  final FolderModel folder;

  const FolderScreen({super.key, required this.folder});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  late FolderModel _currentFolder;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            FolderIcon(color: _currentFolder.color, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _currentFolder.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename folder')),
              const PopupMenuItem(value: 'color', child: Text('Change color')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete folder', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubfoldersSection(
            parentId: _currentFolder.id,
            onSubfolderPopped: _refresh,
          ),
          const Divider(height: 1),
          Expanded(
            child: _FilesSection(
              folderId: _currentFolder.id,
              onFileRenamed: (file) => _renameFileDialog(context, file),
            ),
          ),
        ],
      ),
      floatingActionButton: _AddFab(
        folderId: _currentFolder.id,
        onSubfolderCreated: _refresh,
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    final folderProvider = context.read<FolderProvider>();
    switch (action) {
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
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Folder?'),
            content: Text('Delete "${_currentFolder.name}" and all its nested subfolders & files?'),
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
        if (confirm == true && context.mounted) {
          await folderProvider.deleteFolder(_currentFolder.id);
          if (context.mounted) Navigator.pop(context);
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
  final VoidCallback onSubfolderPopped;

  const _SubfoldersSection({
    required this.parentId,
    required this.onSubfolderPopped,
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
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: subfolders.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  final folder = subfolders[index];
                  return SizedBox(
                    width: 96,
                    child: FolderCard(
                      folder: folder,
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
  final Function(FileItemModel) onFileRenamed;

  const _FilesSection({
    required this.folderId,
    required this.onFileRenamed,
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
                const Text('Tap + below to import PDF, image, or any file', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return FileTile(
              file: file,
              onRename: () => onFileRenamed(file),
              onDelete: () => provider.deleteFile(file.id),
              onDownloadToggle: () => provider.toggleDownload(file.id),
            );
          },
        );
      },
    );
  }
}

class _AddFab extends StatelessWidget {
  final String folderId;
  final VoidCallback onSubfolderCreated;

  const _AddFab({
    required this.folderId,
    required this.onSubfolderCreated,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showAddOptions(context),
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    );
  }

  void _showAddOptions(BuildContext context) {
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
                context.read<FileProvider>().importFiles(folderId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder, color: Colors.amber),
              title: const Text('New Subfolder'),
              subtitle: const Text('Create a colored nested folder'),
              onTap: () {
                Navigator.pop(context);
                _createSubfolder(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSubfolder(BuildContext context) async {
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

    if (result == true && controller.text.trim().isNotEmpty && context.mounted) {
      await context.read<FolderProvider>().createFolder(
            controller.text.trim(),
            selectedColor,
            folderId,
          );
      onSubfolderCreated();
    }
    controller.dispose();
  }
}
