import 'package:flutter/material.dart';

class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const KeyboardShortcutsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const shortcuts = [
      ('F1', 'Keyboard Shortcuts Help', 'Opens this shortcut reference cheatsheet'),
      ('F2 or /', 'Omni-Search / Barcode Focus', 'Immediately places cursor into product barcode search'),
      ('F4', 'Pay & Checkout', 'Opens the tender & payment modal with quick cash options'),
      ('F5', 'Cart Discount', 'Apply percentage or fixed currency discount on entire cart'),
      ('F6', 'Park / Hold Order', 'Temporarily shelves the active cart to serve the next customer'),
      ('F7', 'Retrieve Parked Orders', 'Displays list of previously suspended/parked customer orders'),
      ('F8', 'Clear Active Cart', 'Removes all items from current cart after confirmation'),
      ('Ctrl + P', 'Reprint Receipt', 'Directly prints duplicate thermal receipt for last transaction'),
      ('Esc', 'Dismiss Modal / Close', 'Closes any open overlay, dialog or slide-over drawer'),
    ];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.keyboard, color: Color(0xFF0F766E)),
          ),
          const SizedBox(width: 12),
          const Text(
            'Keyboard Shortcuts Cheatsheet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Designed for rapid, mouse-free counter operation by cashiers.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: shortcuts.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (ctx, i) {
                  final (key, title, desc) = shortcuts[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                offset: const Offset(0, 1),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                          child: Text(
                            key,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                desc,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
          ),
          child: const Text('Got It'),
        ),
      ],
    );
  }
}
