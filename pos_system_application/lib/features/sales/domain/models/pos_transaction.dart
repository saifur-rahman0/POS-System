import 'package:flutter/material.dart';
import '../../../checkout/domain/models/sale_receipt.dart';
import '../../../purchasing/domain/models/purchase_order.dart';
import '../../../expenses/domain/models/expense.dart';
import '../../../expenses/domain/models/account_transfer.dart';
import 'sale_summary.dart';

/// Categories of financial and store transactions.
enum PosTransactionType {
  sale,
  purchase,
  payment,
  expense,
  returnRefund,
  transfer;

  String get label {
    switch (this) {
      case PosTransactionType.sale:
        return 'Sale';
      case PosTransactionType.purchase:
        return 'Purchase';
      case PosTransactionType.payment:
        return 'Payment';
      case PosTransactionType.expense:
        return 'Expense';
      case PosTransactionType.returnRefund:
        return 'Return / Refund';
      case PosTransactionType.transfer:
        return 'Transfer';
    }
  }

  IconData get icon {
    switch (this) {
      case PosTransactionType.sale:
        return Icons.point_of_sale;
      case PosTransactionType.purchase:
        return Icons.shopping_bag_outlined;
      case PosTransactionType.payment:
        return Icons.payments_outlined;
      case PosTransactionType.expense:
        return Icons.receipt_outlined;
      case PosTransactionType.returnRefund:
        return Icons.assignment_return_outlined;
      case PosTransactionType.transfer:
        return Icons.swap_horiz_outlined;
    }
  }
}

/// Cashflow direction of the transaction relative to the store liquidity.
enum TransactionDirection {
  inflow,
  outflow,
  neutral;

  String get label {
    switch (this) {
      case TransactionDirection.inflow:
        return 'Inflow (+)';
      case TransactionDirection.outflow:
        return 'Outflow (-)';
      case TransactionDirection.neutral:
        return 'Internal (⇄)';
    }
  }
}

/// Date range filter presets for transactions ledger.
enum TransactionDateFilter {
  allTime('All Time'),
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 Days'),
  thisMonth('This Month');

  final String label;
  const TransactionDateFilter(this.label);
}

/// Standardized line item for sale or purchase transactions.
class PosTransactionItemModel {
  final String productName;
  final String sku;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  const PosTransactionItemModel({
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory PosTransactionItemModel.fromJson(Map<String, dynamic> json) {
    return PosTransactionItemModel(
      productName: json['product_name'] as String? ?? 'Item',
      sku: json['sku'] as String? ?? '-',
      quantity: double.tryParse(json['quantity']?.toString() ?? '1') ?? 1.0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      lineTotal: double.tryParse(json['line_total']?.toString() ?? '0') ?? 0.0,
    );
  }
}

/// Payment tender detail applied to a transaction.
class PosTransactionPaymentModel {
  final String method;
  final double amount;
  final String? reference;
  final String status;
  final DateTime paidAt;

  const PosTransactionPaymentModel({
    required this.method,
    required this.amount,
    this.reference,
    this.status = 'CONFIRMED',
    required this.paidAt,
  });
}

/// Authoritative unified transaction model representing Sales, Purchases, Payments, Expenses, and Transfers.
class PosTransactionModel {
  final String id;
  final PosTransactionType type;
  final TransactionDirection direction;
  final String referenceNo;
  final String partyName; // Customer / Supplier / Payee / Transfer Source
  final double amount;
  final double? subtotal;
  final double? tax;
  final double? discount;
  final double? paidAmount;
  final double? dueAmount;
  final String paymentMethod;
  final String status;
  final DateTime timestamp;
  final int itemCount;
  final String? note;
  final String? cashierName;
  final String? branchId;
  final List<PosTransactionItemModel> items;
  final List<PosTransactionPaymentModel> payments;
  final dynamic rawModel;

  const PosTransactionModel({
    required this.id,
    required this.type,
    required this.direction,
    required this.referenceNo,
    required this.partyName,
    required this.amount,
    this.subtotal,
    this.tax,
    this.discount,
    this.paidAmount,
    this.dueAmount,
    required this.paymentMethod,
    required this.status,
    required this.timestamp,
    this.itemCount = 0,
    this.note,
    this.cashierName,
    this.branchId,
    this.items = const [],
    this.payments = const [],
    this.rawModel,
  });

  bool get isInflow => direction == TransactionDirection.inflow;
  bool get isOutflow => direction == TransactionDirection.outflow;

  Color get directionColor {
    switch (direction) {
      case TransactionDirection.inflow:
        return const Color(0xFF0F766E); // Teal / Green
      case TransactionDirection.outflow:
        return const Color(0xFFDC2626); // Crimson Red
      case TransactionDirection.neutral:
        return const Color(0xFF2563EB); // Royal Blue
    }
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'RECEIVED':
      case 'APPROVED':
      case 'CONFIRMED':
        return const Color(0xFF0F766E);
      case 'PARTIAL':
      case 'PARTIALLY_REFUNDED':
      case 'ORDERED':
      case 'PENDING_APPROVAL':
        return const Color(0xFFD97706); // Amber
      case 'REFUNDED':
        return const Color(0xFF4F46E5); // Indigo
      case 'VOIDED':
      case 'CANCELLED':
      case 'REJECTED':
        return const Color(0xFFDC2626); // Red
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  /// Create transaction from SaleSummaryModel
  factory PosTransactionModel.fromSaleSummary(SaleSummaryModel sale) {
    final isRefunded = sale.status.toUpperCase() == 'REFUNDED';
    final isVoid = sale.status.toUpperCase() == 'VOIDED';

    return PosTransactionModel(
      id: sale.id,
      type: isRefunded ? PosTransactionType.returnRefund : PosTransactionType.sale,
      direction: isRefunded ? TransactionDirection.outflow : (isVoid ? TransactionDirection.neutral : TransactionDirection.inflow),
      referenceNo: sale.receiptNo,
      partyName: (sale.customerName != null && sale.customerName!.trim().isNotEmpty)
          ? sale.customerName!
          : 'Walk-in Customer',
      amount: sale.grandTotal,
      subtotal: sale.subtotal,
      tax: sale.taxTotal,
      discount: sale.discountTotal,
      paidAmount: sale.paidTotal,
      dueAmount: sale.dueTotal,
      paymentMethod: sale.dueTotal > 0 && sale.paidTotal == 0 ? 'DUE' : 'CASH / CARD',
      status: sale.status,
      timestamp: sale.createdAt,
      itemCount: sale.itemsCount,
      cashierName: sale.cashierId,
      rawModel: sale,
    );
  }

  /// Create transaction from SaleReceiptModel (detailed receipt)
  factory PosTransactionModel.fromSaleReceipt(SaleReceiptModel receipt) {
    final isRefunded = receipt.status.toUpperCase() == 'REFUNDED';
    final primaryMethod = receipt.payments.isNotEmpty
        ? receipt.payments.map((p) => p.method).toSet().join(', ')
        : 'CASH';

    final items = receipt.items
        .map((it) => PosTransactionItemModel(
              productName: it.productName,
              sku: it.sku ?? '-',
              quantity: it.quantity,
              unitPrice: it.unitPrice,
              lineTotal: it.lineTotal,
            ))
        .toList();

    final payments = receipt.payments
        .map((p) => PosTransactionPaymentModel(
              method: p.method,
              amount: p.amount,
              reference: p.reference,
              status: p.status,
              paidAt: receipt.createdAt,
            ))
        .toList();

    return PosTransactionModel(
      id: receipt.id,
      type: isRefunded ? PosTransactionType.returnRefund : PosTransactionType.sale,
      direction: isRefunded ? TransactionDirection.outflow : TransactionDirection.inflow,
      referenceNo: receipt.receiptNo,
      partyName: (receipt.customerName != null && receipt.customerName!.trim().isNotEmpty)
          ? receipt.customerName!
          : 'Walk-in Customer',
      amount: receipt.financials.grandTotal,
      subtotal: receipt.financials.subtotal,
      tax: receipt.financials.taxTotal,
      discount: receipt.financials.discountTotal,
      paidAmount: receipt.financials.paidTotal,
      dueAmount: receipt.financials.dueTotal,
      paymentMethod: primaryMethod,
      status: receipt.status,
      timestamp: receipt.createdAt,
      itemCount: receipt.items.length,
      cashierName: receipt.cashierId,
      items: items,
      payments: payments,
      rawModel: receipt,
    );
  }

  /// Create transaction from PurchaseOrderModel
  factory PosTransactionModel.fromPurchaseOrder(PurchaseOrderModel po) {
    final items = po.items
        .map((it) => PosTransactionItemModel(
              productName: it.productName ?? 'Item',
              sku: it.sku ?? '-',
              quantity: it.quantity,
              unitPrice: it.unitCost,
              lineTotal: it.lineTotal,
            ))
        .toList();

    final payments = po.payments
        .map((p) => PosTransactionPaymentModel(
              method: p.method,
              amount: p.amount,
              reference: p.reference,
              status: 'CONFIRMED',
              paidAt: p.paidAt,
            ))
        .toList();

    final primaryMethod = payments.isNotEmpty
        ? payments.map((p) => p.method).toSet().join(', ')
        : (po.paidTotal > 0 ? 'CASH' : 'PENDING');

    return PosTransactionModel(
      id: po.id,
      type: PosTransactionType.purchase,
      direction: TransactionDirection.outflow,
      referenceNo: po.referenceNo,
      partyName: po.supplierName ?? 'Supplier #${po.supplierId.substring(0, 6)}',
      amount: po.total,
      subtotal: po.subtotal,
      discount: po.discount,
      paidAmount: po.paidTotal,
      dueAmount: po.dueBalance,
      paymentMethod: primaryMethod,
      status: po.status,
      timestamp: po.createdAt,
      itemCount: po.items.length,
      note: po.notes,
      branchId: po.branchId,
      items: items,
      payments: payments,
      rawModel: po,
    );
  }

  /// Create standalone payment transaction from PurchasePaymentModel
  factory PosTransactionModel.fromPurchasePayment(
    PurchasePaymentModel payment, {
    String? referenceNo,
    String? supplierName,
  }) {
    return PosTransactionModel(
      id: payment.id,
      type: PosTransactionType.payment,
      direction: TransactionDirection.outflow,
      referenceNo: 'PAY-${payment.id.substring(0, 8).toUpperCase()}',
      partyName: supplierName != null ? 'Disbursement: $supplierName' : 'Supplier Payment',
      amount: payment.amount,
      paidAmount: payment.amount,
      dueAmount: 0.0,
      paymentMethod: payment.method,
      status: 'CONFIRMED',
      timestamp: payment.paidAt,
      itemCount: 1,
      note: 'Payment against PO ${referenceNo ?? payment.purchaseId}',
      rawModel: payment,
    );
  }

  /// Create standalone payment transaction from customer SaleReceiptPaymentModel
  factory PosTransactionModel.fromSalePayment(
    SaleReceiptPaymentModel payment, {
    String? receiptNo,
    String? customerName,
    DateTime? timestamp,
  }) {
    return PosTransactionModel(
      id: payment.id,
      type: PosTransactionType.payment,
      direction: TransactionDirection.inflow,
      referenceNo: 'PAY-${payment.id.substring(0, 8).toUpperCase()}',
      partyName: customerName != null ? 'Collection: $customerName' : 'Customer Payment',
      amount: payment.amount,
      paidAmount: payment.amount,
      dueAmount: 0.0,
      paymentMethod: payment.method,
      status: payment.status,
      timestamp: timestamp ?? DateTime.now(),
      itemCount: 1,
      note: 'Payment for Receipt ${receiptNo ?? ''}'.trim(),
      rawModel: payment,
    );
  }

  /// Create transaction from ExpenseModel
  factory PosTransactionModel.fromExpense(ExpenseModel expense) {
    return PosTransactionModel(
      id: expense.id,
      type: PosTransactionType.expense,
      direction: TransactionDirection.outflow,
      referenceNo: expense.voucherNo ?? 'VCH-${expense.id.substring(0, 8).toUpperCase()}',
      partyName: (expense.payee != null && expense.payee!.trim().isNotEmpty)
          ? expense.payee!
          : (expense.categoryName ?? expense.category),
      amount: expense.amount,
      paidAmount: expense.amount,
      dueAmount: 0.0,
      paymentMethod: expense.paymentMethod,
      status: expense.approvalStatus,
      timestamp: expense.createdAt,
      itemCount: 1,
      note: expense.note ?? (expense.categoryName != null ? 'Category: ${expense.categoryName}' : null),
      branchId: expense.branchId,
      rawModel: expense,
    );
  }

  /// Create transaction from AccountTransferModel
  factory PosTransactionModel.fromTransfer(AccountTransferModel transfer) {
    final fromName = transfer.fromAccountName ?? 'Source Account';
    final toName = transfer.toAccountName ?? 'Destination Account';

    return PosTransactionModel(
      id: transfer.id,
      type: PosTransactionType.transfer,
      direction: TransactionDirection.neutral,
      referenceNo: transfer.referenceNo ?? 'TRF-${transfer.id.substring(0, 8).toUpperCase()}',
      partyName: '$fromName ➔ $toName',
      amount: transfer.amount,
      paidAmount: transfer.amount,
      dueAmount: 0.0,
      paymentMethod: 'INTERNAL_TRANSFER',
      status: 'COMPLETED',
      timestamp: transfer.transferDate,
      itemCount: 1,
      note: transfer.note,
      rawModel: transfer,
    );
  }
}

/// Filter state for the unified transactions hub.
class TransactionFilterState {
  final PosTransactionType? typeFilter;
  final TransactionDirection? directionFilter;
  final String paymentMethodFilter;
  final TransactionDateFilter dateFilter;
  final DateTimeRange? customDateRange;
  final String searchQuery;
  final String? branchId;

  const TransactionFilterState({
    this.typeFilter,
    this.directionFilter,
    this.paymentMethodFilter = 'ALL',
    this.dateFilter = TransactionDateFilter.allTime,
    this.customDateRange,
    this.searchQuery = '',
    this.branchId,
  });

  TransactionFilterState copyWith({
    PosTransactionType? typeFilter,
    bool clearTypeFilter = false,
    TransactionDirection? directionFilter,
    bool clearDirectionFilter = false,
    String? paymentMethodFilter,
    TransactionDateFilter? dateFilter,
    DateTimeRange? customDateRange,
    bool clearCustomDateRange = false,
    String? searchQuery,
    String? branchId,
  }) {
    return TransactionFilterState(
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      directionFilter: clearDirectionFilter ? null : (directionFilter ?? this.directionFilter),
      paymentMethodFilter: paymentMethodFilter ?? this.paymentMethodFilter,
      dateFilter: dateFilter ?? this.dateFilter,
      customDateRange: clearCustomDateRange ? null : (customDateRange ?? this.customDateRange),
      searchQuery: searchQuery ?? this.searchQuery,
      branchId: branchId ?? this.branchId,
    );
  }
}

/// Aggregated Financial KPIs computed from active filtered transactions.
class TransactionKpis {
  final double totalInflow;
  final int inflowCount;
  final double totalOutflow;
  final int outflowCount;
  final double netCashFlow;
  final int totalCount;
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;
  final Map<String, double> methodTotals;

  const TransactionKpis({
    required this.totalInflow,
    required this.inflowCount,
    required this.totalOutflow,
    required this.outflowCount,
    required this.netCashFlow,
    required this.totalCount,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.methodTotals,
  });

  factory TransactionKpis.fromTransactions(List<PosTransactionModel> txns) {
    double inflow = 0.0;
    int inCount = 0;
    double outflow = 0.0;
    int outCount = 0;
    double sales = 0.0;
    double purchases = 0.0;
    double expenses = 0.0;
    final Map<String, double> methods = {};

    for (final t in txns) {
      // Inflow vs Outflow
      if (t.direction == TransactionDirection.inflow) {
        inflow += t.amount;
        inCount++;
      } else if (t.direction == TransactionDirection.outflow) {
        outflow += t.amount;
        outCount++;
      }

      // By Type
      switch (t.type) {
        case PosTransactionType.sale:
          sales += t.amount;
          break;
        case PosTransactionType.purchase:
          purchases += t.amount;
          break;
        case PosTransactionType.expense:
          expenses += t.amount;
          break;
        default:
          break;
      }

      // Payment method tracking
      final m = t.paymentMethod.toUpperCase().trim();
      if (m.isNotEmpty) {
        methods[m] = (methods[m] ?? 0.0) + t.amount;
      }
    }

    return TransactionKpis(
      totalInflow: inflow,
      inflowCount: inCount,
      totalOutflow: outflow,
      outflowCount: outCount,
      netCashFlow: inflow - outflow,
      totalCount: txns.length,
      totalSales: sales,
      totalPurchases: purchases,
      totalExpenses: expenses,
      methodTotals: methods,
    );
  }
}
