class AuthUserModel {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? phone;
  final bool isActive;
  final String role;
  final List<String> permissions;

  const AuthUserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.phone,
    this.isActive = true,
    this.role = 'CASHIER',
    this.permissions = const [],
  });

  bool get isAdmin =>
      role.toUpperCase() == 'ADMIN' ||
      role.toUpperCase() == 'OWNER' ||
      permissions.contains('*') ||
      permissions.contains('admin');

  bool get isManager =>
      isAdmin || role.toUpperCase() == 'MANAGER';

  bool get isCashier =>
      role.toUpperCase() == 'CASHIER';

  bool get isStockKeeper =>
      role.toUpperCase() == 'STOCK_KEEPER' || role.toUpperCase() == 'STOCK';

  bool hasPermission(String code) {
    if (isAdmin) return true;
    if (permissions.contains('*')) return true;
    return permissions.contains(code);
  }

  String get roleDisplayName {
    switch (role.toUpperCase()) {
      case 'ADMIN':
      case 'OWNER':
        return 'Stall Owner';
      case 'MANAGER':
        return 'Store Manager';
      case 'STOCK_KEEPER':
      case 'STOCK':
        return 'Stock Keeper';
      case 'CASHIER':
      default:
        return 'Cashier';
    }
  }

  bool canAccessSection(String section) {
    if (isAdmin) return true;

    switch (section.toLowerCase()) {
      case 'pos':
        return hasPermission('pos') || hasPermission('pos:access');
      case 'catalog':
        return hasPermission('catalog') ||
            hasPermission('catalog:read') ||
            hasPermission('inventory:read');
      case 'purchasing':
        return hasPermission('purchasing') || hasPermission('purchasing:read');
      case 'sales':
        return hasPermission('sales') || hasPermission('sales:read');
      case 'expenses':
        return hasPermission('expenses') || hasPermission('expenses:read');
      case 'accounts':
        return hasPermission('accounts') || hasPermission('accounting:read');
      case 'customers':
        return hasPermission('customers') || hasPermission('customers:read');
      case 'transfers':
        return hasPermission('transfers') || hasPermission('transfers:read');
      case 'reports':
        return hasPermission('reports') || hasPermission('reports:read');
      case 'settings':
        return hasPermission('settings') || hasPermission('settings:read');
      case 'users':
        return hasPermission('users:manage');
      default:
        return false;
    }
  }

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['permissions'];
    List<String> permsList = const [];
    if (rawPerms is List) {
      permsList = rawPerms.map((e) => e.toString()).toList();
    }

    return AuthUserModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['username']?.toString() ?? 'Cashier',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      isActive: json['is_active'] == true,
      role: json['role']?.toString().toUpperCase() ?? 'CASHIER',
      permissions: permsList,
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
      'role': role,
      'permissions': permissions,
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
