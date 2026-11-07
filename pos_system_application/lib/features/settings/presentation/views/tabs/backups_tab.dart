import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_client/features/settings/presentation/controllers/settings_controller.dart';

class BackupsTab extends ConsumerStatefulWidget {
  const BackupsTab({super.key});

  @override
  ConsumerState<BackupsTab> createState() => _BackupsTabState();
}

class _BackupsTabState extends ConsumerState<BackupsTab> {
  bool _isBackingUp = false;
  String? _restoringId;

  void _showRestoreDialog(String backupId, String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Confirm Database Restore'),
          ],
        ),
        content: Text(
          'Are you sure you want to restore the database from archive:\n\n'
          '$fileName\n\n'
          'This will verify the physical archive integrity, match the SHA-256 checksum, and load snapshot tables.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _restoringId = backupId);

              final res = await ref.read(backupsListProvider.notifier).restoreBackup(backupId);

              if (mounted) {
                setState(() => _restoringId = null);
                if (res != null) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF0F766E)),
                          SizedBox(width: 8),
                          Text('Restore Completed'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Archive: ${res.fileName}'),
                          const SizedBox(height: 8),
                          Text('Status: ${res.status}'),
                          Text('Tables Verified: ${res.tablesVerified}'),
                          Text('Records Restored: ${res.recordsCount}'),
                          const SizedBox(height: 8),
                          Text(res.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                      ],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to restore backup archive'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Restore Database'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backupsAsync = ref.watch(backupsListProvider);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm:ss a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Action Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Database Backups & Disaster Recovery', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                      'Export gzip-compressed snapshots with SHA-256 checksums for safe disaster recovery',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Archives',
                    onPressed: () => ref.read(backupsListProvider.notifier).loadBackups(),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _isBackingUp
                        ? null
                        : () async {
                            setState(() => _isBackingUp = true);
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await ref.read(backupsListProvider.notifier).createBackup();
                            if (!mounted) return;
                            setState(() => _isBackingUp = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Compressed database backup archive created successfully!'
                                    : 'Failed to create backup archive'),
                                backgroundColor: ok ? const Color(0xFF0F766E) : Colors.red,
                              ),
                            );
                          },
                    icon: _isBackingUp
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.backup),
                    label: Text(_isBackingUp ? 'Archiving...' : 'Create Backup Now'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Backups List
          backupsAsync.when(
            data: (backups) {
              if (backups.isEmpty) {
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No backup archives recorded yet.'),
                          SizedBox(height: 4),
                          Text('Click "Create Backup Now" above to generate your first snapshot.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: backups.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final b = backups[idx];
                    final isRestoring = _restoringId == b.id;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE6FFFA),
                        child: Icon(Icons.folder_zip, color: Color(0xFF0F766E)),
                      ),
                      title: Row(
                        children: [
                          Text(b.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              b.backupType,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Size: ${b.formattedSize} • Created: ${dateFmt.format(b.createdAt)}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          Text(
                            'SHA-256: ${b.checksum.length > 24 ? "${b.checksum.substring(0, 24)}..." : b.checksum}',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: b.status == 'COMPLETED' ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              b.status,
                              style: TextStyle(
                                color: b.status == 'COMPLETED' ? Colors.green.shade800 : Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F766E),
                              side: const BorderSide(color: Color(0xFF0F766E)),
                            ),
                            onPressed: isRestoring ? null : () => _showRestoreDialog(b.id, b.fileName),
                            icon: isRestoring
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.restore, size: 16),
                            label: Text(isRestoring ? 'Restoring...' : 'Restore'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Failed to load backup archives: $e', style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.read(backupsListProvider.notifier).loadBackups(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
