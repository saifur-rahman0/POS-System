class AuthUserModel {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? phone;
  final bool isActive;

  const AuthUserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.phone,
    this.isActive = true,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['username']?.toString() ?? 'Cashier',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      isActive: json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'email': email,
      'phone': phone,
      'is_active': isActive,
    };
  }
}

class BusinessInfoModel {
  final String id;
  final String name;
  final String currency;
  final String timezone;

  const BusinessInfoModel({
    required this.id,
    required this.name,
    this.currency = 'BDT',
    this.timezone = 'Asia/Dhaka',
  });

  factory BusinessInfoModel.fromJson(Map<String, dynamic> json) {
    return BusinessInfoModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Retail POS Store',
      currency: json['currency']?.toString() ?? 'BDT',
      timezone: json['timezone']?.toString() ?? 'Asia/Dhaka',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'currency': currency,
      'timezone': timezone,
    };
  }
}

class AuthResponseModel {
  final String accessToken;
  final String tokenType;
  final AuthUserModel user;
  final BusinessInfoModel business;

  const AuthResponseModel({
    required this.accessToken,
    this.tokenType = 'bearer',
    required this.user,
    required this.business,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['access_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      business: BusinessInfoModel.fromJson(json['business'] as Map<String, dynamic>? ?? {}),
    );
  }
}

