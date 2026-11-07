import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/features/settings/presentation/controllers/settings_controller.dart';

class StoreProfileTab extends ConsumerStatefulWidget {
  const StoreProfileTab({super.key});

  @override
  ConsumerState<StoreProfileTab> createState() => _StoreProfileTabState();
}

class _StoreProfileTabState extends ConsumerState<StoreProfileTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _legalNameController;
  late TextEditingController _timezoneController;
  late TextEditingController _currencyController;
  late TextEditingController _taxRateController;
  late TextEditingController _receiptHeaderController;
  late TextEditingController _receiptFooterController;

  bool _initialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _legalNameController = TextEditingController();
    _timezoneController = TextEditingController(text: 'Asia/Dhaka');
    _currencyController = TextEditingController(text: 'BDT');
    _taxRateController = TextEditingController(text: '5.0');
    _receiptHeaderController = TextEditingController(text: 'Retail POS — Store Receipt');
    _receiptFooterController = TextEditingController(text: 'Thank you for shopping with us! Please come again.');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _legalNameController.dispose();
    _timezoneController.dispose();
    _currencyController.dispose();
    _taxRateController.dispose();
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  void _populate(dynamic settings) {
    if (!_initialized && settings != null) {
      _nameController.text = settings.name;
      _legalNameController.text = settings.legalName ?? '';
      _timezoneController.text = settings.timezone;
      _currencyController.text = settings.currency;
      _taxRateController.text = settings.defaultTaxRate.toStringAsFixed(1);
      _receiptHeaderController.text = settings.receiptHeader ?? '';
      _receiptFooterController.text = settings.receiptFooter ?? '';
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(businessSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        _populate(settings);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Form Column (Left)
              Expanded(
                flex: 3,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
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
                              Row(
                                children: [
                                  const Icon(Icons.storefront, color: Color(0xFF0F766E), size: 28),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        settings.name,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        settings.legalName ?? 'Enterprise Retail Chain',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6FFFA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Active Store Profile',
                                      style: TextStyle(color: Color(0xFF0F766E), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Store / Display Name *',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.business),
                                      ),
                                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _legalNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Legal Entity / Company Name',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.gavel),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _currencyController,
                                      decoration: const InputDecoration(
                                        labelText: 'Currency Symbol / Code (e.g. BDT, USD)',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.payments_outlined),
                                      ),
                                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _timezoneController,
                                      decoration: const InputDecoration(
                                        labelText: 'Store Operating Timezone',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.schedule),
                                      ),
                                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _taxRateController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Default Sales VAT / Tax Rate (%)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.percent),
                                  suffixText: '%',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Receipt Customization Card
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
                              const Text(
                                'Thermal Receipt Customization',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Headers and footers printed on ESC/POS 80mm/58mm sales slips',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _receiptHeaderController,
                                decoration: const InputDecoration(
                                  labelText: 'Receipt Header Message',
                                  border: OutlineInputBorder(),
                                  hintText: 'e.g. Retail POS — Flagship Store',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _receiptFooterController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Receipt Footer Policy / Note',
                                  border: OutlineInputBorder(),
                                  hintText: 'e.g. Goods once sold cannot be returned without receipt.',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  setState(() => _isSaving = true);
                                  final messenger = ScaffoldMessenger.of(context);

                                  final ok = await ref.read(businessSettingsProvider.notifier).updateProfile(
                                        name: _nameController.text.trim(),
                                        legalName: _legalNameController.text.trim(),
                                        timezone: _timezoneController.text.trim(),
                                        currency: _currencyController.text.trim(),
                                      );

                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Store profile updated successfully'
                                          : 'Failed to update store profile'),
                                      backgroundColor: ok ? const Color(0xFF0F766E) : Colors.red,
                                    ),
                                  );
                                },
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? 'Saving...' : 'Save Profile Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Live Receipt Mockup Preview (Right)
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 2,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.receipt_long, color: Color(0xFF0F766E)),
                            SizedBox(width: 8),
                            Text('Live Thermal Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _nameController.text.isNotEmpty ? _nameController.text : 'Store Name',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              if (_legalNameController.text.isNotEmpty)
                                Text(
                                  _legalNameController.text,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                _receiptHeaderController.text.isNotEmpty
                                    ? _receiptHeaderController.text
                                    : 'Thermal Receipt',
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const Text('----------------------------------------', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('REC-20261107-001', style: TextStyle(fontSize: 11)),
                                  Text('CASHIER: Admin', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                              const Text('----------------------------------------', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Sample Item (1x)', style: TextStyle(fontSize: 11)),
                                  Text('100.00', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                              const Text('----------------------------------------', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal:', style: TextStyle(fontSize: 11)),
                                  Text('${_currencyController.text} 100.00', style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('VAT (${_taxRateController.text}%):', style: const TextStyle(fontSize: 11)),
                                  Text(
                                    '${_currencyController.text} ${(100.0 * (double.tryParse(_taxRateController.text) ?? 5.0) / 100).toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(
                                    '${_currencyController.text} ${(100.0 + (100.0 * (double.tryParse(_taxRateController.text) ?? 5.0) / 100)).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _receiptFooterController.text.isNotEmpty
                                    ? _receiptFooterController.text
                                    : 'Thank you!',
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
            Text('Failed to load store profile: $e', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(businessSettingsProvider.notifier).loadSettings(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
