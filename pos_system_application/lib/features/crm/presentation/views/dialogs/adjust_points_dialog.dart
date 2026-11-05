import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/features/crm/presentation/controllers/crm_controller.dart';

class AdjustPointsDialog extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final int currentPoints;

  const AdjustPointsDialog({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.currentPoints,
  });

  static Future<void> show(
    BuildContext context, {
    required String customerId,
    required String customerName,
    required int currentPoints,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AdjustPointsDialog(
        customerId: customerId,
        customerName: customerName,
        currentPoints: currentPoints,
      ),
    );
  }

  @override
  ConsumerState<AdjustPointsDialog> createState() => _AdjustPointsDialogState();
}

class _AdjustPointsDialogState extends ConsumerState<AdjustPointsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pointsCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _isAddition = true;

  @override
  void dispose() {
    _pointsCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final rawPoints = int.parse(_pointsCtrl.text.trim());
    final deltaPoints = _isAddition ? rawPoints : -rawPoints;

    final ok = await ref.read(crmControllerProvider.notifier).adjustCustomerPoints(
          widget.customerId,
          deltaPoints,
          _reasonCtrl.text.trim(),
        );

    if (ok && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isAddition ? 'Awarded $rawPoints points' : 'Deducted $rawPoints points')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(crmControllerProvider);

    return AlertDialog(
      title: Text('Adjust Points — ${widget.customerName}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Balance:', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      '${widget.currentPoints} pts',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F766E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('+ Award Bonus'), icon: Icon(Icons.add_circle_outline)),
                  ButtonSegment(value: false, label: Text('- Deduct Points'), icon: Icon(Icons.remove_circle_outline)),
                ],
                selected: {_isAddition},
                onSelectionChanged: (set) => setState(() => _isAddition = set.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pointsCtrl,
                decoration: const InputDecoration(labelText: 'Points Amount', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final parsed = int.tryParse(v);
                  if (parsed == null || parsed <= 0) return 'Must be greater than 0';
                  if (!_isAddition && parsed > widget.currentPoints) {
                    return 'Cannot deduct more than balance (${widget.currentPoints})';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason / Reference Note', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
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
              : const Text('Confirm Adjustment'),
        ),
      ],
    );
  }
}
