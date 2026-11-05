import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/features/crm/presentation/controllers/crm_controller.dart';

class IssueGiftCardDialog extends ConsumerStatefulWidget {
  const IssueGiftCardDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const IssueGiftCardDialog(),
    );
  }

  @override
  ConsumerState<IssueGiftCardDialog> createState() => _IssueGiftCardDialogState();
}

class _IssueGiftCardDialogState extends ConsumerState<IssueGiftCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _balanceCtrl = TextEditingController(text: '1000');
  final _pinCtrl = TextEditingController(text: '1234');
  final _customCardNumCtrl = TextEditingController();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _recipientEmailCtrl = TextEditingController();
  bool _autoGenerateNumber = true;

  @override
  void dispose() {
    _balanceCtrl.dispose();
    _pinCtrl.dispose();
    _customCardNumCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _recipientEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      if (!_autoGenerateNumber && _customCardNumCtrl.text.trim().isNotEmpty)
        'card_number': _customCardNumCtrl.text.trim(),
      'pin': _pinCtrl.text.trim(),
      'initial_balance': double.parse(_balanceCtrl.text.trim()),
      if (_recipientNameCtrl.text.trim().isNotEmpty) 'recipient_name': _recipientNameCtrl.text.trim(),
      if (_recipientPhoneCtrl.text.trim().isNotEmpty) 'recipient_phone': _recipientPhoneCtrl.text.trim(),
      if (_recipientEmailCtrl.text.trim().isNotEmpty) 'recipient_email': _recipientEmailCtrl.text.trim(),
    };

    final card = await ref.read(crmControllerProvider.notifier).issueGiftCard(data);
    if (card != null && mounted) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Gift Card Issued Successfully'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card Number: ${card.cardNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('PIN: ${_pinCtrl.text.trim()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F766E))),
              const SizedBox(height: 8),
              Text('Initial Balance: ৳ ${card.initialBalance.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              const Text('Please write down or give the PIN to the recipient. It will not be shown again in plaintext.', style: TextStyle(color: Colors.grey)),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(crmControllerProvider);

    return AlertDialog(
      title: const Text('Issue New Gift Card'),
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
                        controller: _balanceCtrl,
                        decoration: const InputDecoration(labelText: 'Initial Value (৳)', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final p = double.tryParse(v);
                          if (p == null || p <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pinCtrl,
                        decoration: const InputDecoration(labelText: 'Security PIN (4-8 digits)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.length < 4 || v.length > 8) {
                            return '4-8 digits';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Auto-generate Card Number (GC-XXXX-XXXX-XXXX)'),
                  value: _autoGenerateNumber,
                  activeColor: const Color(0xFF0F766E),
                  onChanged: (val) => setState(() => _autoGenerateNumber = val ?? true),
                ),
                if (!_autoGenerateNumber) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _customCardNumCtrl,
                    decoration: const InputDecoration(labelText: 'Custom Card Number', border: OutlineInputBorder()),
                    validator: (v) {
                      if (!_autoGenerateNumber && (v == null || v.isEmpty)) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recipientNameCtrl,
                  decoration: const InputDecoration(labelText: 'Recipient Name (Optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _recipientPhoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _recipientEmailCtrl,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
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
              : const Text('Issue Card'),
        ),
      ],
    );
  }
}
