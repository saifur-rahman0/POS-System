import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/features/crm/domain/models/promotional_campaign.dart';
import 'package:pos_client/features/crm/presentation/controllers/crm_controller.dart';

class CampaignDialog extends ConsumerStatefulWidget {
  final PromotionalCampaignModel? campaign;

  const CampaignDialog({super.key, this.campaign});

  static Future<void> show(BuildContext context, {PromotionalCampaignModel? campaign}) {
    return showDialog(
      context: context,
      builder: (_) => CampaignDialog(campaign: campaign),
    );
  }

  @override
  ConsumerState<CampaignDialog> createState() => _CampaignDialogState();
}

class _CampaignDialogState extends ConsumerState<CampaignDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _messageCtrl;
  String _targetSegment = 'ALL';
  String _channel = 'SMS';

  final List<String> _segments = [
    'ALL',
    'CHAMPIONS',
    'LOYAL',
    'POTENTIAL_LOYALIST',
    'NEW_CUSTOMER',
    'PROMISING',
    'NEED_ATTENTION',
    'AT_RISK',
    'HIBERNATING',
    'LOST',
  ];

  final List<String> _channels = ['SMS', 'EMAIL', 'WHATSAPP', 'IN_APP'];

  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    _titleCtrl = TextEditingController(text: c?.title ?? '');
    _messageCtrl = TextEditingController(text: c?.messageTemplate ?? '');
    _targetSegment = c?.targetSegment ?? 'ALL';
    _channel = c?.channel ?? 'SMS';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'title': _titleCtrl.text.trim(),
      'target_segment': _targetSegment,
      'channel': _channel,
      'message_template': _messageCtrl.text.trim(),
    };

    final notifier = ref.read(crmControllerProvider.notifier);
    final bool ok;
    if (widget.campaign == null) {
      ok = await notifier.createCampaign(data);
    } else {
      ok = await notifier.updateCampaign(widget.campaign!.id, data);
    }

    if (ok && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.campaign == null ? 'Campaign created' : 'Campaign updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(crmControllerProvider);
    final isEdit = widget.campaign != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Promotional Campaign' : 'Create Promotional Campaign'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Campaign Title', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _targetSegment,
                        decoration: const InputDecoration(labelText: 'Target Audience Cohort', border: OutlineInputBorder()),
                        items: _segments
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _targetSegment = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _channel,
                        decoration: const InputDecoration(labelText: 'Broadcast Channel', border: OutlineInputBorder()),
                        items: _channels.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _channel = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Message Template / Broadcast Copy',
                    border: OutlineInputBorder(),
                    hintText: 'Dear Customer, enjoy 15% off this weekend! Use code VIP15.',
                  ),
                  maxLines: 4,
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
              : Text(isEdit ? 'Save Changes' : 'Create Campaign'),
        ),
      ],
    );
  }
}
