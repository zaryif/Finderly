import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:finderly/models/file_item_model.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class FileTile extends StatelessWidget {
  final FileItemModel file;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onDownloadToggle;

  const FileTile({
    super.key,
    required this.file,
    this.onRename,
    this.onDelete,
    this.onDownloadToggle,
  });

  @override
  Widget build(BuildContext context) {
    final ext = file.fileExtension;
    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
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
        leading: _buildFileIcon(ext),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${file.formattedSize} • ${_formatDate(file.createdAt)}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 20),
              tooltip: 'Share file',
              onPressed: () {
                Share.shareXFiles([XFile(file.localPath)], text: file.name);
              },
            ),
            IconButton(
              icon: Icon(
                file.isDownloaded
                    ? Icons.check_circle
                    : Icons.cloud_download_outlined,
                color: file.isDownloaded ? Colors.green : null,
              ),
              tooltip: file.isDownloaded
                  ? 'Available Offline (Tap to remove)'
                  : 'Download for Offline',
              onPressed: onDownloadToggle,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (val) {
                if (val == 'rename') onRename?.call();
                if (val == 'delete') onDelete?.call();
                if (val == 'share') Share.shareXFiles([XFile(file.localPath)], text: file.name);
                if (val == 'open') OpenFile.open(file.localPath);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'open', child: Text('Open File')),
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
        onTap: () => OpenFile.open(file.localPath),
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
        size: 32,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  IconData _fallbackIcon(String type) {
    return switch (type) {
      'pdf' => Icons.picture_as_pdf,
      'doc' || 'docx' => Icons.description,
      'xls' || 'xlsx' => Icons.table_chart,
      'ppt' || 'pptx' => Icons.slideshow,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => Icons.image,
      'mp4' || 'mov' || 'avi' => Icons.video_file,
      'mp3' || 'wav' || 'aac' => Icons.audio_file,
      'zip' || 'rar' || '7z' => Icons.folder_zip,
      'txt' => Icons.text_snippet,
      _ => Icons.insert_drive_file,
    };
  }

  Color _fallbackColor(String type) {
    return switch (type) {
      'pdf' => Colors.red,
      'doc' || 'docx' => Colors.blue,
      'xls' || 'xlsx' => Colors.green,
      'ppt' || 'pptx' => Colors.orange,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => Colors.purple,
      'mp4' || 'mov' || 'avi' => Colors.indigo,
      'mp3' || 'wav' || 'aac' => Colors.pink,
      'zip' || 'rar' || '7z' => Colors.brown,
      _ => Colors.grey,
    };
  }
}
