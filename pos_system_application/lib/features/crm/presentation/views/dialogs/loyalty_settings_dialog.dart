import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/features/crm/domain/models/loyalty_settings.dart';
import 'package:pos_client/features/crm/presentation/controllers/crm_controller.dart';

class LoyaltySettingsDialog extends ConsumerStatefulWidget {
  final LoyaltySettingsModel settings;

  const LoyaltySettingsDialog({super.key, required this.settings});

  static Future<void> show(BuildContext context, LoyaltySettingsModel settings) {
    return showDialog(
      context: context,
      builder: (_) => LoyaltySettingsDialog(settings: settings),
    );
  }

  @override
  ConsumerState<LoyaltySettingsDialog> createState() => _LoyaltySettingsDialogState();
}

class _LoyaltySettingsDialogState extends ConsumerState<LoyaltySettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late bool _isEnabled;
  late final TextEditingController _earnRateCtrl;
  late final TextEditingController _redeemRateCtrl;
  late final TextEditingController _minRedeemCtrl;
  late final TextEditingController _expiryDaysCtrl;
  late final TextEditingController _maxDiscountCtrl;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.settings.isEnabled;
    _earnRateCtrl = TextEditingController(text: widget.settings.earnRate.toString());
    _redeemRateCtrl = TextEditingController(text: widget.settings.redeemRate.toString());
    _minRedeemCtrl = TextEditingController(text: widget.settings.minRedeemPoints.toString());
    _expiryDaysCtrl = TextEditingController(text: widget.settings.pointsExpiryDays.toString());
    _maxDiscountCtrl = TextEditingController(text: widget.settings.maxCartDiscountPct.toString());
  }

  @override
  void dispose() {
    _earnRateCtrl.dispose();
    _redeemRateCtrl.dispose();
    _minRedeemCtrl.dispose();
    _expiryDaysCtrl.dispose();
    _maxDiscountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'is_enabled': _isEnabled,
      'earn_rate': double.parse(_earnRateCtrl.text.trim()),
      'redeem_rate': double.parse(_redeemRateCtrl.text.trim()),
      'min_redeem_points': int.parse(_minRedeemCtrl.text.trim()),
      'points_expiry_days': int.parse(_expiryDaysCtrl.text.trim()),
      'max_cart_discount_pct': double.parse(_maxDiscountCtrl.text.trim()),
    };

    final ok = await ref.read(crmControllerProvider.notifier).updateSettings(data);
    if (ok && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loyalty settings saved successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(crmControllerProvider);

    return AlertDialog(
      title: const Text('Configure Loyalty Program'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Enable Loyalty Points Program'),
                  subtitle: const Text('Allow customers to earn and redeem points at POS'),
                  value: _isEnabled,
                  activeThumbColor: const Color(0xFF0F766E),
                  onChanged: (val) => setState(() => _isEnabled = val),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _earnRateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Earn Rate (Points per ৳100 spent)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _redeemRateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Redeem Rate (৳ value per 1 point)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minRedeemCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Points Required to Redeem',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expiryDaysCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Points Expiry (Days, 0 = Never)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _maxDiscountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Max Order Total Discount (%)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
          onPressed: state.isLoading ? null : _submit,
          child: state.isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save Settings'),
        ),
      ],
    );
  }
}
