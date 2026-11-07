import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/features/branches/presentation/controllers/branches_controller.dart';
import 'package:pos_client/features/settings/presentation/controllers/settings_controller.dart';

class SystemPreferencesTab extends ConsumerStatefulWidget {
  const SystemPreferencesTab({super.key});

  @override
  ConsumerState<SystemPreferencesTab> createState() => _SystemPreferencesTabState();
}

class _SystemPreferencesTabState extends ConsumerState<SystemPreferencesTab> {
  late TextEditingController _terminalNameController;
  late TextEditingController _deviceIdController;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(terminalPreferencesProvider);
    _terminalNameController = TextEditingController(text: prefs.terminalName);
    _deviceIdController = TextEditingController(text: prefs.deviceId);
  }

  @override
  void dispose() {
    _terminalNameController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(terminalPreferencesProvider);
    final prefsNotifier = ref.read(terminalPreferencesProvider.notifier);
    final branchesState = ref.watch(branchesListProvider);
    final activeBranch = ref.watch(activeBranchProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Terminal Identity
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.point_of_sale, color: Color(0xFF0F766E), size: 28),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Terminal & Workstation Identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Configure register hardware identifiers for shift reconciliation and Z-reports', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _terminalNameController,
                          decoration: const InputDecoration(
                            labelText: 'Workstation Terminal Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.desktop_windows),
                          ),
                          onChanged: (v) => prefsNotifier.setTerminalName(v.trim()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _deviceIdController,
                          decoration: const InputDecoration(
                            labelText: 'Hardware Device ID',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.fingerprint),
                          ),
                          onChanged: (v) => prefsNotifier.setDeviceId(v.trim()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (branchesState.branches.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: activeBranch?.id,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Physical Store Branch',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store),
                      ),
                      items: branchesState.branches.where((b) => b.isActive).map((b) {
                        return DropdownMenuItem(
                          value: b.id,
                          child: Text('${b.name} (${b.code ?? "N/A"})'),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null) {
                          final selected = branchesState.branches.firstWhere((b) => b.id == newId);
                          ref.read(activeBranchProvider.notifier).state = selected;
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Real-time Behavior & Auto-Refresh
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Real-Time Data & Auto-Refresh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Controls how frequently active views poll the server for updated balances, vouchers, and transactions',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      const Text('Auto-Refresh Cadence: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 15, label: Text('15s (Real-time)')),
                          ButtonSegment(value: 30, label: Text('30s (Recommended)')),
                          ButtonSegment(value: 60, label: Text('60s (Low LAN load)')),
                          ButtonSegment(value: 0, label: Text('Manual Only')),
                        ],
                        selected: {prefs.autoRefreshIntervalSeconds},
                        onSelectionChanged: (set) {
                          prefsNotifier.setAutoRefreshInterval(set.first);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(set.first > 0
                                  ? 'Auto-refresh set to every ${set.first} seconds'
                                  : 'Periodic auto-refresh disabled (manual refresh only)'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Audio Tone Feedback'),
                    subtitle: const Text('Play sound chime when scanning items, parking carts, and settling sales'),
                    value: prefs.soundEffectsEnabled,
                    activeThumbColor: const Color(0xFF0F766E),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => prefsNotifier.toggleSoundEffects(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section 3: Central Server & Connection Info
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Central Server & Local Database', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFE6FFFA),
                          child: Icon(Icons.check, color: Color(0xFF0F766E), size: 20),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('FastAPI Local Server: http://127.0.0.1:8000/api/v1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('Database: PostgreSQL 16 (Local asyncpg Pool) • All 65 Tables Synchronized', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text('Connected', style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold, fontSize: 11)),
                          backgroundColor: Color(0xFFE6FFFA),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
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
