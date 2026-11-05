import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/pricing_controller.dart';

class PriceListDialog extends ConsumerStatefulWidget {
  const PriceListDialog({super.key});

  @override
  ConsumerState<PriceListDialog> createState() => _PriceListDialogState();
}

class _PriceListDialogState extends ConsumerState<PriceListDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _currency = 'BDT';
  bool _isDefault = false;
  final bool _isActive = true;
  String? _selectedGroupId;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(pricingControllerProvider.notifier).createPriceList({
      'name': _nameController.text.trim(),
      'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      'currency': _currency,
      'is_default': _isDefault,
      'is_active': _isActive,
      'customer_group_id': _selectedGroupId,
    });

    if (mounted && success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pricingControllerProvider);
    final groupsAsync = ref.watch(customerGroupsProvider);

    return AlertDialog(
      title: const Text('New Price List'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Price List Name *',
                  hintText: 'e.g. Retail Standard, Wholesale Tier 1',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              groupsAsync.when(
                data: (groups) => DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(
                    labelText: 'Target Customer Group (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedGroupId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None (General / Default)'),
                    ),
                    ...groups.map(
                      (g) => DropdownMenuItem<String?>(
                        value: g.id,
                        child: Text(g.name),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedGroupId = val),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                      ),
                      value: _currency,
                      items: const [
                        DropdownMenuItem(value: 'BDT', child: Text('BDT (৳)')),
                        DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                      ],
                      onChanged: (val) => setState(() => _currency = val ?? 'BDT'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Default List'),
                      value: _isDefault,
                      onChanged: (val) => setState(() => _isDefault = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: state.isLoading ? null : _submit,
          child: state.isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Price List'),
        ),
      ],
    );
  }
}
