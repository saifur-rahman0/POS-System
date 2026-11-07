import '../../../../core/utils/parsers.dart';

class LicenseModel {
  final String businessId;
  final String licenseKeyId;
  final String status; // ACTIVE, EXPIRING_SOON, EXPIRED, TRIAL
  final String planName;
  final int deviceLimit;
  final List<String> features;
  final int? daysRemaining;
  final bool isPerpetual;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final String message;

  const LicenseModel({
    required this.businessId,
    required this.licenseKeyId,
    required this.status,
    required this.planName,
    required this.deviceLimit,
    this.features = const [],
    this.daysRemaining,
    this.isPerpetual = false,
    this.activatedAt,
    this.expiresAt,
    required this.message,
  });

  factory LicenseModel.fromJson(Map<String, dynamic> json) {
    return LicenseModel(
      businessId: json['business_id']?.toString() ?? '',
      licenseKeyId: json['license_key_id']?.toString() ?? 'UNLICENSED',
      status: json['status']?.toString() ?? 'TRIAL',
      planName: json['plan_name']?.toString() ?? 'EVALUATION',
      deviceLimit: parseInt(json['device_limit'], 1),
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      daysRemaining: json['days_remaining'] != null ? parseInt(json['days_remaining']) : null,
      isPerpetual: json['is_perpetual'] as bool? ?? false,
      activatedAt: json['activated_at'] != null ? DateTime.tryParse(json['activated_at'].toString()) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      message: json['message']?.toString() ?? '',
    );
  }

  bool get isActive => status == 'ACTIVE' || (status == 'TRIAL' && (daysRemaining ?? 0) > 0);
}
