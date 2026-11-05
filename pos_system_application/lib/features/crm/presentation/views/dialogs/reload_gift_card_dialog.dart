import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/features/crm/domain/models/gift_card.dart';
import 'package:pos_client/features/crm/presentation/controllers/crm_controller.dart';

class ReloadGiftCardDialog extends ConsumerStatefulWidget {
  final GiftCardModel card;

  const ReloadGiftCardDialog({super.key, required this.card});

  static Future<void> show(BuildContext context, GiftCardModel card) {
    return showDialog(
      context: context,
      builder: (_) => ReloadGiftCardDialog(card: card),
    );
  }

  @override
  ConsumerState<ReloadGiftCardDialog> createState() => _ReloadGiftCardDialogState();
}

class _ReloadGiftCardDialogState extends ConsumerState<ReloadGiftCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController(text: '500');
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text.trim());
    final ok = await ref.read(crmControllerProvider.notifier).reloadGiftCard(
          widget.card.id,
          amount,
          reference: _refCtrl.text.trim().isNotEmpty ? _refCtrl.text.trim() : null,
          notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        );

    if (ok && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gift card balance reloaded with ৳ ${amount.toStringAsFixed(2)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(crmControllerProvider);

    return AlertDialog(
      title: Text('Reload Card — ${widget.card.cardNumber}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Balance:'),
                    Text('৳ ${widget.card.currentBalance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F766E))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Reload Amount (৳)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final p = double.tryParse(v);
                  if (p == null || p <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _refCtrl,
                decoration: const InputDecoration(labelText: 'Payment Reference (e.g. Cash, Card Tx)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
              ),
            ],
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
              : const Text('Confirm Reload'),
        ),
      ],
    );
  }
}
