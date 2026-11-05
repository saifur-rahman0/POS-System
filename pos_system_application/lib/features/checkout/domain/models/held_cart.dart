import 'cart_item.dart';

class HeldCartModel {
  final String id;
  final String businessId;
  final String branchId;
  final String cashierId;
  final String? customerId;
  final String? customerName;
  final String? label;
  final List<CartItemModel> items;
  final double cartDiscount;
  final double taxRate;
  final double deliveryCharge;
  final String? notes;
  final DateTime createdAt;

  const HeldCartModel({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.cashierId,
    this.customerId,
    this.customerName,
    this.label,
    required this.items,
    this.cartDiscount = 0.0,
    this.taxRate = 0.0,
    this.deliveryCharge = 0.0,
    this.notes,
    required this.createdAt,
  });

  int get itemsCount => items.fold(0, (acc, item) => acc + item.quantity.round());

  double get subtotal => items.fold(0.0, (acc, item) => acc + (item.quantity * item.unitPrice));

  double get grandTotal {
    final disc = items.fold(0.0, (acc, item) => acc + item.lineDiscount) + cartDiscount;
    final discountedSub = (subtotal - disc).clamp(0.0, double.infinity);
    final tax = discountedSub * (taxRate / 100.0);
    return double.parse((discountedSub + tax + deliveryCharge).toStringAsFixed(4));
  }

  factory HeldCartModel.fromJson(Map<String, dynamic> json) {
    List<CartItemModel> parsedItems = [];
    final rawItems = json['cart_items_json'];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((item) {
            if (item is Map) {
              return CartItemModel.fromJson(Map<String, dynamic>.from(item));
            }
            return null;
          })
          .whereType<CartItemModel>()
          .toList();
    }

    return HeldCartModel(
      id: json['id'].toString(),
      businessId: json['business_id'].toString(),
      branchId: json['branch_id'].toString(),
      cashierId: json['cashier_id'].toString(),
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString(),
      label: json['label']?.toString(),
      items: parsedItems,
      cartDiscount: double.tryParse((json['cart_discount'] ?? 0).toString()) ?? 0.0,
      taxRate: double.tryParse((json['tax_rate'] ?? 0).toString()) ?? 0.0,
      deliveryCharge: double.tryParse((json['delivery_charge'] ?? 0).toString()) ?? 0.0,
      notes: json['notes']?.toString(),
      createdAt: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
    );
  }
}

