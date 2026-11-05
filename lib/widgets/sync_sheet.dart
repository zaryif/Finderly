import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:finderly/services/sync_service.dart';
import 'package:finderly/providers/folder_provider.dart';
import 'package:finderly/database/local_db.dart';

class SyncSheet extends StatefulWidget {
  const SyncSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SyncSheet(),
    );
  }

  @override
  State<SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends State<SyncSheet> {
  final _ipController = TextEditingController();
  final _webdavUrlController = TextEditingController();
  final _webdavUserController = TextEditingController();
  final _webdavPassController = TextEditingController();
  bool _isWebDavExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadWebDavSettings();
  }

  Future<void> _loadWebDavSettings() async {
    final url = await LocalDB.instance.getSetting('webdav_url');
    final user = await LocalDB.instance.getSetting('webdav_user');
    final pass = await LocalDB.instance.getSetting('webdav_pass');
    if (mounted) {
      setState(() {
        _webdavUrlController.text = url ?? '';
        _webdavUserController.text = user ?? '';
        _webdavPassController.text = pass ?? '';
      });
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _webdavUrlController.dispose();
    _webdavUserController.dispose();
    _webdavPassController.dispose();
    super.dispose();
  }

  Future<void> _syncWithIp(String ip, int port) async {
    try {
      final stats = await SyncService.instance.syncWithPeer(ip, port: port);
      if (mounted) {
        context.read<FolderProvider>().loadFolders(null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(stats.summary),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _showDirectConnectDialog() async {
    _ipController.text = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect to Device IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the IP address shown on your other device (e.g., 192.168.1.50):',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                hintText: '192.168.1.X',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
              ),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final raw = _ipController.text.trim();
              Navigator.pop(ctx);
              if (raw.isNotEmpty) {
                final parts = raw.split(':');
                final ip = parts[0];
                final port = parts.length > 1
                    ? int.tryParse(parts[1]) ?? SyncService.defaultHttpPort
                    : SyncService.defaultHttpPort;
                _syncWithIp(ip, port);
              }
            },
            child: const Text('Connect & Sync'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportVault() async {
    try {
      final file = await SyncService.instance.exportVault();
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Finderly Vault Backup',
        text: 'Finderly Vault archive containing all folders and files.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importVault() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (res == null || res.files.isEmpty || res.files.first.path == null) {
        return;
      }

      final stats = await SyncService.instance.importVault(res.files.first.path!);
      if (mounted) {
        context.read<FolderProvider>().loadFolders(null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(stats.summary),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveAndSyncWebDav() async {
    final url = _webdavUrlController.text.trim();
    final user = _webdavUserController.text.trim();
    final pass = _webdavPassController.text.trim();

    await LocalDB.instance.setSetting('webdav_url', url);
    await LocalDB.instance.setSetting('webdav_user', user);
    await LocalDB.instance.setSetting('webdav_pass', pass);

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a WebDAV server URL')),
      );
      return;
    }

    try {
      final stats = await SyncService.instance.syncWithWebDav(
        serverUrl: url,
        username: user,
        password: pass,
      );
      if (mounted) {
        context.read<FolderProvider>().loadFolders(null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(stats.summary),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WebDAV sync error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListenableBuilder(
        listenable: SyncService.instance,
        builder: (context, _) {
          final sync = SyncService.instance;
          final isSyncing = sync.status == SyncStatus.syncing;
          final peers = sync.discoveredPeers;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.sync_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Finderly Sync Center',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            sync.syncMessage ?? 'Real-time multi-device sync',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSyncing
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              if (isSyncing)
                LinearProgressIndicator(
                  value: sync.progress > 0 ? sync.progress : null,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                ),

              const Divider(height: 1),

              // Scrollable content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // --- SECTION 1: This Device Status Card ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: sync.isServerRunning
                                      ? Colors.greenAccent.shade700
                                      : Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This Device: ${sync.deviceName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.network_wifi_outlined,
                                  size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Text(
                                'Local Endpoint: http://${sync.localIp ?? '127.0.0.1'}:${sync.port}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                tooltip: 'Copy IP endpoint',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                    text: 'http://${sync.localIp}:${sync.port}',
                                  ));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Endpoint copied to clipboard'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- SECTION 2: Nearby Wi-Fi Devices ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nearby Devices (Wi-Fi)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: isSyncing ? null : _showDirectConnectDialog,
                          icon: const Icon(Icons.add_link, size: 16),
                          label: const Text('Direct IP'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (peers.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.radar_rounded,
                              size: 36,
                              color: theme.colorScheme.primary.withOpacity(0.6),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Listening for Finderly devices on your Wi-Fi...',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Open Finderly on your phone or laptop on the same network, or click "Direct IP".',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ...peers.map((peer) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.primary.withOpacity(0.12),
                                child: Icon(
                                  peer.deviceName.toLowerCase().contains('mac') ||
                                          peer.deviceName.toLowerCase().contains('windows')
                                      ? Icons.laptop_mac
                                      : Icons.smartphone,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                peer.deviceName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                peer.endpoint,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: FilledButton.tonal(
                                onPressed: isSyncing
                                    ? null
                                    : () => _syncWithIp(peer.ip, peer.port),
                                child: const Text('Sync Now'),
                              ),
                            ),
                          )),

                    const SizedBox(height: 24),

                    // --- SECTION 3: Vault Backup & Restore ---
                    const Text(
                      'Vault Backup & Migration',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Export your entire vault (all folders + actual files) into a single .finderly package to move across devices offline.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSyncing ? null : _exportVault,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Export Vault'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSyncing ? null : _importVault,
                            icon: const Icon(Icons.download_for_offline_outlined),
                            label: const Text('Import Vault'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION 4: Cloud / WebDAV (Nextcloud / ownCloud) ---
                    Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: _isWebDavExpanded,
                        onExpansionChanged: (v) => setState(() => _isWebDavExpanded = v),
                        leading: const Icon(Icons.cloud_queue_rounded),
                        title: const Text(
                          'WebDAV / Nextcloud Sync',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Optional remote sync over the internet',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _webdavUrlController,
                                  decoration: const InputDecoration(
                                    labelText: 'Server URL',
                                    hintText: 'https://cloud.example.com/remote.php/dav/files/user/',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _webdavUserController,
                                        decoration: const InputDecoration(
                                          labelText: 'Username',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _webdavPassController,
                                        obscureText: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Password',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: isSyncing ? null : _saveAndSyncWebDav,
                                    icon: const Icon(Icons.cloud_upload_outlined),
                                    label: const Text('Save & Sync to Cloud'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

