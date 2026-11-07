import '../../../../core/utils/parsers.dart';

class BusinessSettingsModel {
  final String id;
  final String name;
  final String? legalName;
  final String timezone;
  final String currency;
  final double defaultTaxRate;
  final String? receiptHeader;
  final String? receiptFooter;
  final bool isActive;

  const BusinessSettingsModel({
    required this.id,
    required this.name,
    this.legalName,
    this.timezone = 'Asia/Dhaka',
    this.currency = 'BDT',
    this.defaultTaxRate = 5.0,
    this.receiptHeader = 'Retail POS — Store Receipt',
    this.receiptFooter = 'Thank you for shopping with us! Please come again.',
    this.isActive = true,
  });

  factory BusinessSettingsModel.fromJson(Map<String, dynamic> json) {
    return BusinessSettingsModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Retail POS Store',
      legalName: json['legal_name'] as String?,
      timezone: json['timezone'] as String? ?? 'Asia/Dhaka',
      currency: json['currency'] as String? ?? 'BDT',
      defaultTaxRate: parseDouble(json['default_tax_rate'], 5.0),
      receiptHeader: json['receipt_header'] as String? ?? 'Retail POS — Store Receipt',
      receiptFooter: json['receipt_footer'] as String? ?? 'Thank you for shopping with us!',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (legalName != null) 'legal_name': legalName,
      'timezone': timezone,
      'currency': currency,
    };
  }

  BusinessSettingsModel copyWith({
    String? id,
    String? name,
    String? legalName,
    String? timezone,
    String? currency,
    double? defaultTaxRate,
    String? receiptHeader,
    String? receiptFooter,
    bool? isActive,
  }) {
    return BusinessSettingsModel(
      id: id ?? this.id,
      name: name ?? this.name,
      legalName: legalName ?? this.legalName,
      timezone: timezone ?? this.timezone,
      currency: currency ?? this.currency,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      isActive: isActive ?? this.isActive,
    );
  }
}
