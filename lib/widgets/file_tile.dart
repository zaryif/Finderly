import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:finderly/models/file_item_model.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class FileTile extends StatelessWidget {
  final FileItemModel file;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;
  final VoidCallback? onDownloadToggle;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback? onSelectToggle;

  const FileTile({
    super.key,
    required this.file,
    this.onRename,
    this.onMove,
    this.onDelete,
    this.onDownloadToggle,
    this.isSelecting = false,
    this.isSelected = false,
    this.onSelectToggle,
  });

  @override
  Widget build(BuildContext context) {
    final ext = file.fileExtension;
    return Container(
      color: isSelected ? Colors.blue.withOpacity(0.12) : Colors.transparent,
      child: Slidable(
        enabled: !isSelecting,
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            if (onMove != null)
              SlidableAction(
                onPressed: (_) => onMove?.call(),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                icon: Icons.drive_file_move_outlined,
                label: 'Move',
              ),
            if (onRename != null)
              SlidableAction(
                onPressed: (_) => onRename?.call(),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                icon: Icons.edit,
                label: 'Rename',
              ),
            SlidableAction(
              onPressed: (_) => onDelete?.call(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelecting) ...[
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.blue : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 8),
              ],
              _buildFileIcon(ext),
            ],
          ),
          title: Text(
            file.name,
            softWrap: true,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          subtitle: Text(
            '${file.formattedSize} • ${_formatDate(file.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          trailing: isSelecting
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 18),
                      tooltip: 'Share file',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Share.shareXFiles([XFile(file.localPath)], text: file.name);
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        file.isDownloaded
                            ? Icons.check_circle
                            : Icons.cloud_download_outlined,
                        color: file.isDownloaded ? Colors.green : null,
                        size: 18,
                      ),
                      tooltip: file.isDownloaded
                          ? 'Available Offline (Tap to remove)'
                          : 'Download for Offline',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      visualDensity: VisualDensity.compact,
                      onPressed: onDownloadToggle,
                    ),
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'More options',
                      onSelected: (val) {
                        if (val == 'open') OpenFile.open(file.localPath);
                        if (val == 'move') onMove?.call();
                        if (val == 'rename') onRename?.call();
                        if (val == 'share') Share.shareXFiles([XFile(file.localPath)], text: file.name);
                        if (val == 'delete') onDelete?.call();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'open', child: Text('Open File')),
                        const PopupMenuItem(value: 'move', child: Text('Move to Folder...')),
                        const PopupMenuItem(value: 'rename', child: Text('Rename')),
                        const PopupMenuItem(value: 'share', child: Text('Share')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                ),
          onTap: () {
            if (isSelecting) {
              onSelectToggle?.call();
            } else {
              OpenFile.open(file.localPath);
            }
          },
          onLongPress: () {
            if (isSelecting) {
              onSelectToggle?.call();
            } else if (onSelectToggle != null) {
              onSelectToggle!();
            }
          },
        ),
      ),
    );
  }

  Widget _buildFileIcon(String ext) {
    final assetName = switch (ext) {
      'pdf' => 'pdf_icon.png',
      'doc' || 'docx' => 'doc_icon.png',
      'xls' || 'xlsx' => 'xls_icon.png',
      'ppt' || 'pptx' => 'ppt_icon.png',
      'zip' || 'rar' || '7z' => 'zip_icon.png',
      'txt' => 'txt_icon.png',
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => 'image_icon.png',
      'mp4' || 'mov' || 'avi' || 'mkv' => 'video_icon.png',
      'mp3' || 'wav' || 'aac' || 'flac' => 'audio_icon.png',
      _ => 'file_icon.png',
    };

    return Image.asset(
      'assets/icons/$assetName',
      width: 36,
      height: 36,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        _fallbackIcon(ext),
        color: _fallbackColor(ext),
        size: 36,
      ),
    );
  }

  IconData _fallbackIcon(String ext) {
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => Icons.image,
      'mp4' || 'mov' || 'avi' || 'mkv' => Icons.videocam,
      'mp3' || 'wav' || 'aac' || 'flac' => Icons.audiotrack,
      'doc' || 'docx' || 'txt' => Icons.description,
      'xls' || 'xlsx' => Icons.table_chart,
      'ppt' || 'pptx' => Icons.slideshow,
      'zip' || 'rar' || '7z' => Icons.folder_zip,
      _ => Icons.insert_drive_file,
    };
  }

  Color _fallbackColor(String ext) {
    return switch (ext) {
      'pdf' => const Color(0xFFE74C3C),
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => const Color(0xFF4A9EF5),
      'mp4' || 'mov' || 'avi' || 'mkv' => const Color(0xFFE67E22),
      'mp3' || 'wav' || 'aac' || 'flac' => const Color(0xFF9B59B6),
      'doc' || 'docx' || 'txt' => const Color(0xFF2980B9),
      'xls' || 'xlsx' => const Color(0xFF27AE60),
      'ppt' || 'pptx' => const Color(0xFFD35400),
      'zip' || 'rar' || '7z' => const Color(0xFFF39C12),
      _ => const Color(0xFF95A5A6),
    };
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
