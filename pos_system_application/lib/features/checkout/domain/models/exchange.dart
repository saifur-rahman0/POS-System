import 'checkout_request.dart';
import 'payment_tender.dart';
import 'sale_receipt.dart';

class ExchangeItemReturnInput {
  final String originalSaleItemId;
  final double quantity;
  final double? refundAmount;
  final String? reason;

  const ExchangeItemReturnInput({
    required this.originalSaleItemId,
    required this.quantity,
    this.refundAmount,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'original_sale_item_id': originalSaleItemId,
      'quantity': quantity.toStringAsFixed(4),
      if (refundAmount != null) 'refund_amount': refundAmount!.toStringAsFixed(4),
      if (reason != null) 'reason': reason,
    };
  }
}

class ExchangeRequestModel {
  final String idempotencyKey;
  final String? branchId;
  final String originalSaleId;
  final List<ExchangeItemReturnInput> returnItems;
  final List<CheckoutRequestItemModel> newItems;
  final double cartDiscount;
  final double taxRate;
  final double deliveryCharge;
  final List<PaymentTenderInput> payments;
  final String? managerApprovedBy;
  final String? notes;

  const ExchangeRequestModel({
    required this.idempotencyKey,
    this.branchId,
    required this.originalSaleId,
    required this.returnItems,
    required this.newItems,
    this.cartDiscount = 0.0,
    this.taxRate = 0.0,
    this.deliveryCharge = 0.0,
    this.payments = const [],
    this.managerApprovedBy,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'idempotency_key': idempotencyKey,
      if (branchId != null) 'branch_id': branchId,
      'original_sale_id': originalSaleId,
      'return_items': returnItems.map((i) => i.toJson()).toList(),
      'new_items': newItems.map((i) => i.toJson()).toList(),
      'cart_discount': cartDiscount.toStringAsFixed(4),
      'tax_rate': taxRate.toStringAsFixed(4),
      'delivery_charge': deliveryCharge.toStringAsFixed(4),
      'payments': payments.map((p) => p.toJson()).toList(),
      if (managerApprovedBy != null) 'manager_approved_by': managerApprovedBy,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }
}

class ExchangeResultModel {
  final String returnOrderId;
  final String returnNo;
  final double returnTotal;
  final SaleReceiptModel newSale;
  final double netDifference;

  const ExchangeResultModel({
    required this.returnOrderId,
    required this.returnNo,
    required this.returnTotal,
    required this.newSale,
    required this.netDifference,
  });

  factory ExchangeResultModel.fromJson(Map<String, dynamic> json) {
    return ExchangeResultModel(
      returnOrderId: json['return_order_id'].toString(),
      returnNo: json['return_no'].toString(),
      returnTotal: double.tryParse((json['return_total'] ?? 0).toString()) ?? 0.0,
      newSale: SaleReceiptModel.fromJson(Map<String, dynamic>.from(json['new_sale'])),
      netDifference: double.tryParse((json['net_difference'] ?? 0).toString()) ?? 0.0,
    );
  }
}

