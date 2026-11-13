class StaffUserModel {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? phone;
  final bool isActive;
  final String role;
  final String roleLabel;
  final List<String> permissions;

  const StaffUserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.phone,
    this.isActive = true,
    this.role = 'CASHIER',
    this.roleLabel = 'Cashier',
    this.permissions = const [],
  });

  bool get isAdmin =>
      role.toUpperCase() == 'ADMIN' ||
      role.toUpperCase() == 'OWNER' ||
      permissions.contains('*');

  bool get isManager =>
      isAdmin || role.toUpperCase() == 'MANAGER';

  bool get isCashier =>
      role.toUpperCase() == 'CASHIER';

  bool get isStockKeeper =>
      role.toUpperCase() == 'STOCK_KEEPER' || role.toUpperCase() == 'STOCK';

  factory StaffUserModel.fromJson(Map<String, dynamic> json) {
    return StaffUserModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['username']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      isActive: json['is_active'] == true,
      role: json['role']?.toString().toUpperCase() ?? 'CASHIER',
      roleLabel: json['role_label']?.toString() ?? json['role']?.toString() ?? 'Cashier',
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
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
      'role_label': roleLabel,
      'permissions': permissions,
    };
  }
}
