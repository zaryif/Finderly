import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/providers/folder_provider.dart';
import 'package:finderly/services/sync_service.dart';
import 'package:finderly/theme/folder_colors.dart';
import 'package:finderly/widgets/folder_card.dart';
import 'package:finderly/widgets/folder_icon.dart';
import 'package:finderly/widgets/color_picker_dialog.dart';
import 'package:finderly/screens/folder_screen.dart';
import 'package:finderly/screens/search_screen.dart';
import 'package:finderly/widgets/sync_sheet.dart';
import 'package:finderly/widgets/merge_folder_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FolderProvider>().loadFolders(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FolderProvider>(
      builder: (context, folderProvider, _) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Image.asset('assets/icons/logo_icon.png', width: 28, height: 28),
                const SizedBox(width: 10),
                const Text('Finderly', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
              ],
            ),
            actions: [
              // + button at the top
              IconButton(
                icon: const Icon(Icons.add, size: 26),
                tooltip: 'New Folder',
                onPressed: () => _showCreateFolderDialog(context, folderProvider),
              ),
              // Multi-device sync indicator & Sync Center trigger
              ListenableBuilder(
                listenable: SyncService.instance,
                builder: (context, _) {
                  final sync = SyncService.instance;
                  final isSyncing = sync.status == SyncStatus.syncing;
                  final peerCount = sync.discoveredPeers.length;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                peerCount > 0
                                    ? Icons.sync_rounded
                                    : Icons.cloud_outlined,
                                color: peerCount > 0
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                        tooltip: 'Finderly Sync Center (${sync.localIp ?? 'Active'})',
                        onPressed: () => SyncSheet.show(context),
                      ),
                      if (peerCount > 0 && !isSyncing)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 10,
                              minHeight: 10,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search folders and files',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
              ),
            ],
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.black,
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'),
                fit: BoxFit.cover,
                repeat: ImageRepeat.repeat,
              ),
            ),
            child: SafeArea(
              child: _FolderGrid(
                folderProvider: folderProvider,
                onRefresh: () => folderProvider.loadFolders(null),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateFolderDialog(
    BuildContext context,
    FolderProvider provider,
  ) async {
    final nameController = TextEditingController();
    var selectedColor = FolderColor.blue;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New Folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: FolderIcon(color: selectedColor, size: 72),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Folder name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Folder Color: ', style: TextStyle(fontWeight: FontWeight.w500)),
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
                        border: Border.all(color: Colors.black12, width: 2),
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

    if (result == true && nameController.text.trim().isNotEmpty) {
      await provider.createFolder(
        nameController.text.trim(),
        selectedColor,
        null,
      );
    }
    nameController.dispose();
  }
}

class _FolderGrid extends StatelessWidget {
  final FolderProvider folderProvider;
  final VoidCallback onRefresh;

  const _FolderGrid({
    required this.folderProvider,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final folders = folderProvider.folders;

    if (folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FolderIcon(color: FolderColor.blue, size: 84),
            const SizedBox(height: 16),
            const Text(
              'No folders yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "+ New Folder" below to organize your files',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 0.88,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            final folder = folders[index];
            return FolderCard(
              folder: folder,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FolderScreen(folder: folder),
                  ),
                ).then((_) => onRefresh());
              },
              onRename: () => _renameFolder(context, folder),
              onChangeColor: () => _changeColor(context, folder),
              onMerge: () => _mergeFolder(context, folder),
              onDelete: () => _deleteFolder(context, folder),
            );
          },
        );
      },
    );
  }

  int _columnCount(double width) {
    if (width >= 1200) return 6;
    if (width >= 800) return 5;
    if (width >= 600) return 4;
    return 3;
  }

  Future<void> _renameFolder(BuildContext context, FolderModel folder) async {
    final controller = TextEditingController(text: folder.name);
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Rename')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await folderProvider.renameFolder(folder.id, name.trim());
      onRefresh();
    }
    controller.dispose();
  }

  Future<void> _changeColor(BuildContext context, FolderModel folder) async {
    final color = await ColorPickerDialog.show(context, current: folder.color);
    if (color != null) {
      await folderProvider.changeFolderColor(folder.id, color);
      onRefresh();
    }
  }

  Future<void> _mergeFolder(BuildContext context, FolderModel folder) async {
    final target = await MergeFolderDialog.show(context, folder);
    if (target != null && context.mounted) {
      await folderProvider.mergeFolders(folder.id, target.id, refreshParentId: null);
      onRefresh();
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

  Future<void> _deleteFolder(BuildContext context, FolderModel folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Delete "${folder.name}" and all its subfolders and files?'),
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
    if (confirm == true) {
      await folderProvider.deleteFolder(folder.id);
      onRefresh();
    }
  }
}
