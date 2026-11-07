import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../controllers/cart_controller.dart';

class DeliveryChargeDialog extends ConsumerStatefulWidget {
  const DeliveryChargeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const DeliveryChargeDialog(),
    );
  }

  @override
  ConsumerState<DeliveryChargeDialog> createState() =>
      _DeliveryChargeDialogState();
}

class _DeliveryChargeDialogState extends ConsumerState<DeliveryChargeDialog> {
  late TextEditingController _controller;
  final currencyFmt = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

  final List<Map<String, dynamic>> _presets = [
    {'label': 'Free Delivery', 'amount': 0.0},
    {'label': 'Inside City', 'amount': 60.0},
    {'label': 'Outside City', 'amount': 120.0},
    {'label': 'Express / Same Day', 'amount': 150.0},
  ];

  @override
  void initState() {
    super.initState();
    final current = ref.read(cartProvider).deliveryCharge;
    _controller = TextEditingController(
      text: current > 0 ? current.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final val = double.tryParse(_controller.text) ?? 0.0;
    ref.read(cartProvider.notifier).setDeliveryCharge(val);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.local_shipping_outlined, color: Color(0xFF0F766E)),
          SizedBox(width: 8),
          Text('Delivery & Shipping Fee'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Specify shipping or parcel delivery fee to add to this order.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Delivery Charge',
                prefixText: '৳ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quick Presets',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((p) {
                final double amt = (p['amount'] as num).toDouble();
                final String label = p['label'] as String;
                return ActionChip(
                  avatar: amt == 0
                      ? const Icon(Icons.check_circle_outline, size: 16)
                      : null,
                  label: Text('$label (${currencyFmt.format(amt)})'),
                  onPressed: () {
                    setState(() {
                      _controller.text = amt.toStringAsFixed(2);
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _apply,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
          ),
          child: const Text('Apply Fee'),
        ),
      ],
    );
  }
}

