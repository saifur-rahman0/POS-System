import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/features/crm/domain/models/membership_tier.dart';
import 'package:pos_client/features/crm/presentation/controllers/crm_controller.dart';

class MembershipTierDialog extends ConsumerStatefulWidget {
  final MembershipTierModel? tier;

  const MembershipTierDialog({super.key, this.tier});

  static Future<void> show(BuildContext context, {MembershipTierModel? tier}) {
    return showDialog(
      context: context,
      builder: (_) => MembershipTierDialog(tier: tier),
    );
  }

  @override
  ConsumerState<MembershipTierDialog> createState() => _MembershipTierDialogState();
}

class _MembershipTierDialogState extends ConsumerState<MembershipTierDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _minSpendCtrl;
  late final TextEditingController _multiplierCtrl;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _perksCtrl;
  late final TextEditingController _sortOrderCtrl;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final t = widget.tier;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _codeCtrl = TextEditingController(text: t?.code ?? '');
    _minSpendCtrl = TextEditingController(text: t?.minSpend.toString() ?? '0');
    _multiplierCtrl = TextEditingController(text: t?.pointsMultiplier.toString() ?? '1.0');
    _discountCtrl = TextEditingController(text: t?.discountPct.toString() ?? '0');
    _colorCtrl = TextEditingController(text: t?.badgeColor ?? '#64748B');
    _perksCtrl = TextEditingController(text: t?.perksDescription ?? '');
    _sortOrderCtrl = TextEditingController(text: t?.sortOrder.toString() ?? '0');
    _isActive = t?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _minSpendCtrl.dispose();
    _multiplierCtrl.dispose();
    _discountCtrl.dispose();
    _colorCtrl.dispose();
    _perksCtrl.dispose();
    _sortOrderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameCtrl.text.trim(),
      'code': _codeCtrl.text.trim().toUpperCase(),
      'min_spend': double.parse(_minSpendCtrl.text.trim()),
      'points_multiplier': double.parse(_multiplierCtrl.text.trim()),
      'discount_pct': double.parse(_discountCtrl.text.trim()),
      'badge_color': _colorCtrl.text.trim(),
      'perks_description': _perksCtrl.text.trim().isNotEmpty ? _perksCtrl.text.trim() : null,
      'sort_order': int.parse(_sortOrderCtrl.text.trim()),
      'is_active': _isActive,
    };

    final notifier = ref.read(crmControllerProvider.notifier);
    final bool ok;
    if (widget.tier == null) {
      ok = await notifier.createTier(data);
    } else {
      ok = await notifier.updateTier(widget.tier!.id, data);
    }

    if (ok && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.tier == null ? 'Tier created' : 'Tier updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(crmControllerProvider);
    final isEdit = widget.tier != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Membership Tier' : 'Create Membership Tier'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Tier Name (e.g. Gold)', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _codeCtrl,
                        enabled: !isEdit,
                        decoration: const InputDecoration(labelText: 'Code (e.g. GOLD)', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minSpendCtrl,
                        decoration: const InputDecoration(labelText: 'Min Lifetime Spend (৳)', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _multiplierCtrl,
                        decoration: const InputDecoration(labelText: 'Points Multiplier (e.g. 1.5)', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _discountCtrl,
                        decoration: const InputDecoration(labelText: 'Discount Privilege (%)', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _colorCtrl,
                        decoration: const InputDecoration(labelText: 'Badge Hex Color', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _perksCtrl,
                  decoration: const InputDecoration(labelText: 'Perks & Benefits Description', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sortOrderCtrl,
                        decoration: const InputDecoration(labelText: 'Sort Order', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Active'),
                        value: _isActive,
                        activeThumbColor: const Color(0xFF0F766E),
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ),
                  ],
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
              : Text(isEdit ? 'Save Changes' : 'Create Tier'),
        ),
      ],
    );
  }
}
