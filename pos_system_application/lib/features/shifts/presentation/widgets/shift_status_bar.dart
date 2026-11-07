import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/pos_error_card.dart';
import '../../domain/models/register_shift.dart';
import '../controllers/shift_controller.dart';
import 'cash_in_out_dialog.dart';
import 'close_shift_dialog.dart';
import 'open_shift_dialog.dart';
import 'z_report_dialog.dart';

class ShiftStatusBar extends ConsumerWidget {
  const ShiftStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftAsync = ref.watch(currentShiftProvider);

    return shiftAsync.when(
      data: (shift) {
        if (shift != null && shift.isOpen) {
          return _buildActiveShiftBar(context, ref, shift);
        } else {
          return _buildNoActiveShiftBanner(context, ref);
        }
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Checking register shift status...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 18, color: Colors.amber.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Shift status offline: ${cleanErrorMessage(e)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => ref.read(currentShiftProvider.notifier).loadCurrentShift(),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveShiftBar(BuildContext context, WidgetRef ref, RegisterShiftModel shift) {
    final expectedCash = shift.totals?.expectedCash ?? shift.openingCash;
    final openedStr =
        '${shift.openedAt.hour.toString().padLeft(2, '0')}:${shift.openedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Shift #${shift.id.substring(0, 6).toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(
            '($openedStr)',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (shift.cashierName != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                shift.cashierName!,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ],
          const SizedBox(width: 16),
          // Live Expected Drawer Cash Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.point_of_sale, size: 14, color: Colors.teal),
                const SizedBox(width: 4),
                Text(
                  'Drawer: ৳${expectedCash.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Drawer Quick Actions
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => CashInOutDialog(
                  shift: shift,
                  initialType: CashMovementType.cashIn,
                ),
              );
            },
            icon: const Icon(Icons.add, size: 14, color: Colors.green),
            label: const Text('Cash In', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => CashInOutDialog(
                  shift: shift,
                  initialType: CashMovementType.cashOut,
                ),
              );
            },
            icon: const Icon(Icons.remove, size: 14, color: Colors.red),
            label: const Text('Cash Out', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Live Shift Reading (X-Report)',
            icon: const Icon(Icons.receipt_long, size: 18, color: Colors.blueGrey),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => ZReportDialog(shiftId: shift.id),
              );
            },
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => CloseShiftDialog(shift: shift),
              );
            },
            icon: const Icon(Icons.lock_outline, size: 14),
            label: const Text('Close Shift', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    ),
  );
}

Widget _buildNoActiveShiftBanner(BuildContext context, WidgetRef ref) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.amber.shade300),
    ),
    child: Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'No active register shift. Open a shift with starting float to balance the drawer and enable Z-Reports.',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => const OpenShiftDialog(),
            );
          },
          icon: const Icon(Icons.lock_open, size: 14),
          label: const Text('Open Register Shift', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}
}
