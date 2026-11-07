import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_client/features/settings/presentation/controllers/settings_controller.dart';

class LicensingTab extends ConsumerStatefulWidget {
  const LicensingTab({super.key});

  @override
  ConsumerState<LicensingTab> createState() => _LicensingTabState();
}

class _LicensingTabState extends ConsumerState<LicensingTab> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isActivating = false;
  bool _isGenerating = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final licenseAsync = ref.watch(licenseStatusProvider);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // License Status Card
          licenseAsync.when(
            data: (lic) {
              final isGood = lic.isActive;
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isGood ? const Color(0xFF0F766E).withAlpha(80) : Colors.red.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: isGood ? const Color(0xFFE6FFFA) : Colors.red.shade100,
                                child: Icon(
                                  isGood ? Icons.verified : Icons.error_outline,
                                  color: isGood ? const Color(0xFF0F766E) : Colors.red,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Plan: ${lic.planName}',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isGood ? Colors.green.shade100 : Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          lic.status,
                                          style: TextStyle(
                                            color: isGood ? Colors.green.shade800 : Colors.red.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'License ID: ${lic.licenseKeyId}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                lic.isPerpetual
                                    ? 'Perpetual Lifetime'
                                    : '${lic.daysRemaining ?? 0} Days Remaining',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isGood ? const Color(0xFF0F766E) : Colors.red,
                                ),
                              ),
                              if (lic.expiresAt != null)
                                Text(
                                  'Expires: ${dateFmt.format(lic.expiresAt!)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      // Metrics Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetric('Device Limit', '${lic.deviceLimit} Registers / LAN Terminals'),
                          _buildMetric('Type', lic.isPerpetual ? 'Perpetual (No Expiry)' : 'Subscription / Annual'),
                          _buildMetric('Validation Mode', 'Offline Cryptographic HMAC-SHA256'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Entitlements Chips
                      const Text('Licensed Feature Entitlements:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: lic.features.map((f) {
                          return Chip(
                            avatar: const Icon(Icons.check, size: 16, color: Color(0xFF0F766E)),
                            label: Text(f.replaceAll('_', ' ')),
                            backgroundColor: const Color(0xFFE6FFFA),
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to query license status: $e', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // License Activation Form
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
                  const Text('Activate Offline License Token', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Paste an offline cryptographic license certificate issued by your software vendor or administrative portal.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tokenController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'License Certificate Token (Base64)',
                      border: OutlineInputBorder(),
                      hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isGenerating
                            ? null
                            : () async {
                                final lic = ref.read(licenseStatusProvider).valueOrNull;
                                if (lic == null) return;

                                setState(() => _isGenerating = true);
                                final messenger = ScaffoldMessenger.of(context);
                                final token = await ref
                                    .read(licenseStatusProvider.notifier)
                                    .generateDevLicense(lic.businessId);

                                if (!mounted) return;
                                setState(() => _isGenerating = false);
                                if (token != null) {
                                  _tokenController.text = token;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Generated new 1-Year Enterprise development certificate token.'),
                                      backgroundColor: Color(0xFF0F766E),
                                    ),
                                  );
                                }
                              },
                        icon: _isGenerating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.generating_tokens_outlined),
                        label: const Text('Generate Demo Certificate'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: _isActivating
                            ? null
                            : () async {
                                final tok = _tokenController.text.trim();
                                if (tok.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a license token')),
                                  );
                                  return;
                                }

                                setState(() => _isActivating = true);
                                final messenger = ScaffoldMessenger.of(context);
                                final ok = await ref.read(licenseStatusProvider.notifier).activateLicense(tok);

                                if (!mounted) return;
                                setState(() => _isActivating = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? 'License successfully verified and activated offline!'
                                        : 'Failed to verify license token signature'),
                                    backgroundColor: ok ? const Color(0xFF0F766E) : Colors.red,
                                  ),
                                );
                                if (ok) _tokenController.clear();
                              },
                        icon: _isActivating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.key),
                        label: const Text('Verify & Activate Offline'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
