import 'package:flutter/material.dart';
import 'package:finderly/models/folder_model.dart';
import 'package:finderly/providers/folder_provider.dart';
import 'package:finderly/widgets/folder_icon.dart';
import 'package:provider/provider.dart';

class MergeFolderDialog extends StatefulWidget {
  final FolderModel sourceFolder;

  const MergeFolderDialog({super.key, required this.sourceFolder});

  static Future<FolderModel?> show(BuildContext context, FolderModel sourceFolder) {
    return showDialog<FolderModel>(
      context: context,
      builder: (_) => MergeFolderDialog(sourceFolder: sourceFolder),
    );
  }

  @override
  State<MergeFolderDialog> createState() => _MergeFolderDialogState();
}

class _MergeFolderDialogState extends State<MergeFolderDialog> {
  List<FolderModel>? _candidates;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    final provider = context.read<FolderProvider>();
    final candidates = await provider.getMergeCandidates(widget.sourceFolder.id);
    if (mounted) {
      setState(() {
        _candidates = candidates;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.merge_type, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Merge "${widget.sourceFolder.name}"',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : (_candidates == null || _candidates!.isEmpty)
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No other folders available to merge into.\nCreate another folder first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select the destination folder to receive all files and subfolders:',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _candidates!.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final candidate = _candidates![index];
                            return ListTile(
                              leading: FolderIcon(color: candidate.color, size: 36),
                              title: Text(
                                candidate.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: candidate.parentId == null
                                  ? const Text('Root directory', style: TextStyle(fontSize: 11))
                                  : null,
                              trailing: const Icon(Icons.chevron_right, size: 20),
                              onTap: () => _confirmAndMerge(candidate),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _confirmAndMerge(FolderModel target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Folder Merge'),
        content: Text(
          'Are you sure you want to merge all files and subfolders from "${widget.sourceFolder.name}" into "${target.name}"?\n\n"${widget.sourceFolder.name}" will be deleted after its contents are moved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.merge_type, size: 18),
            label: const Text('Merge'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context, target);
    }
  }
}

