import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../auth/domain/models/staff_user_model.dart';
import '../../../../auth/presentation/controllers/users_controller.dart';
import '../../../../../core/localization/app_localizations.dart';

class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({super.key});

  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(usersControllerProvider.notifier).loadUsers();
    });
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
      case 'OWNER':
        return const Color(0xFF7C3AED); // Purple
      case 'MANAGER':
        return const Color(0xFF2563EB); // Blue
      case 'STOCK_KEEPER':
      case 'STOCK':
        return const Color(0xFFD97706); // Amber
      case 'CASHIER':
      default:
        return const Color(0xFF0F766E); // Teal
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
      case 'OWNER':
        return Icons.admin_panel_settings_rounded;
      case 'MANAGER':
        return Icons.badge_rounded;
      case 'STOCK_KEEPER':
      case 'STOCK':
        return Icons.inventory_2_rounded;
      case 'CASHIER':
      default:
        return Icons.point_of_sale_rounded;
    }
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = 'CASHIER';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: Color(0xFF0F766E)),
              SizedBox(width: 10),
              Text('Add New Staff User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username *',
                        hintText: 'e.g. cashier_john',
                        prefixIcon: Icon(Icons.alternate_email, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Username is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password *',
                        hintText: 'Minimum 4 characters',
                        prefixIcon: Icon(Icons.lock_outline, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().length < 4) ? 'Min 4 characters required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'e.g. John Doe',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Full Name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address (Optional)',
                        hintText: 'john@pos.local',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        hintText: '+880 1700 000000',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Role & Permissions *',
                        prefixIcon: Icon(Icons.security, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ADMIN',
                          child: Text('👑 Stall Owner (Admin) — Full unrestricted access (*)'),
                        ),
                        DropdownMenuItem(
                          value: 'MANAGER',
                          child: Text('👔 Store Manager — Sales, Inventory, Reports & Settings'),
                        ),
                        DropdownMenuItem(
                          value: 'CASHIER',
                          child: Text('💳 Cashier — POS Register, Shifts & Customers'),
                        ),
                        DropdownMenuItem(
                          value: 'STOCK_KEEPER',
                          child: Text('📦 Stock Keeper — Catalog, Inventory & Transfers'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Create User'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                final success = await ref.read(usersControllerProvider.notifier).createStaffUser(
                      username: usernameCtrl.text.trim(),
                      password: passwordCtrl.text,
                      displayName: nameCtrl.text.trim(),
                      email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                      phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                      role: selectedRole,
                    );
                if (success && ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Staff member created successfully!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFF0F766E),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(StaffUserModel user) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user.displayName);
    final emailCtrl = TextEditingController(text: user.email ?? '');
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    String selectedRole = user.role.toUpperCase();
    if (!['ADMIN', 'MANAGER', 'CASHIER', 'STOCK_KEEPER'].contains(selectedRole)) {
      selectedRole = 'CASHIER';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFF0F766E)),
              const SizedBox(width: 10),
              Text('Edit ${user.displayName} (@${user.username})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Display Name *',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role & Permissions *',
                        prefixIcon: Icon(Icons.security, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ADMIN',
                          child: Text('👑 Stall Owner (Admin)'),
                        ),
                        DropdownMenuItem(
                          value: 'MANAGER',
                          child: Text('👔 Store Manager'),
                        ),
                        DropdownMenuItem(
                          value: 'CASHIER',
                          child: Text('💳 Cashier'),
                        ),
                        DropdownMenuItem(
                          value: 'STOCK_KEEPER',
                          child: Text('📦 Stock Keeper'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                final success = await ref.read(usersControllerProvider.notifier).updateStaffUser(
                      userId: user.id,
                      displayName: nameCtrl.text.trim(),
                      email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                      phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                      role: selectedRole,
                    );
                if (success && ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('User profile updated successfully!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFF0F766E),
                    ),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(StaffUserModel user) {
    final formKey = GlobalKey<FormState>();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_reset, color: Color(0xFFD97706)),
            const SizedBox(width: 10),
            Text('Reset Password: ${user.username}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter a new password for staff account @${user.username}:',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password *',
                    hintText: 'Minimum 4 characters',
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().length < 4) ? 'Min 4 characters required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final messenger = ScaffoldMessenger.of(context);
              final success = await ref.read(usersControllerProvider.notifier).changePassword(
                    userId: user.id,
                    newPassword: passCtrl.text,
                  );
              if (success && ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Password for @${user.username} has been updated.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF0F766E),
                  ),
                );
              }
            },
            child: const Text('Set Password'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersControllerProvider);
    final loc = ref.watch(appLocalizationsProvider);

    final totalUsers = state.users.length;
    final activeUsers = state.users.where((u) => u.isActive).length;
    final admins = state.users.where((u) => u.isAdmin).length;
    final cashiers = state.users.where((u) => u.isCashier).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.tr('staff_permissions', 'Staff & Role-Based Permissions'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create staff accounts, configure role permissions, and control terminal access',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Refresh Staff List',
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => ref.read(usersControllerProvider.notifier).loadUsers(),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Add Staff Member', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _showAddUserDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Overview Metric Chips
          Row(
            children: [
              _buildMetricChip(
                icon: Icons.people_alt_rounded,
                label: 'Total Staff',
                value: '$totalUsers',
                color: const Color(0xFF0F766E),
              ),
              const SizedBox(width: 12),
              _buildMetricChip(
                icon: Icons.check_circle_outline,
                label: 'Active Accounts',
                value: '$activeUsers',
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(width: 12),
              _buildMetricChip(
                icon: Icons.admin_panel_settings_rounded,
                label: 'Stall Owners / Admins',
                value: '$admins',
                color: const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 12),
              _buildMetricChip(
                icon: Icons.point_of_sale_rounded,
                label: 'Cashiers',
                value: '$cashiers',
                color: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Users Table Card
          Card(
            elevation: 1,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: state.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                    ),
                  )
                : state.users.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'No staff accounts found. Click "Add Staff Member" to add one.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          horizontalMargin: 20,
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(label: Text('Staff Member', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Role / Access', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: state.users.map((u) {
                            final roleColor = _getRoleColor(u.role);
                            final roleIcon = _getRoleIcon(u.role);

                            return DataRow(
                              cells: [
                                // Staff Member
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: roleColor.withValues(alpha: 0.15),
                                        child: Text(
                                          u.displayName.isNotEmpty
                                              ? u.displayName[0].toUpperCase()
                                              : u.username[0].toUpperCase(),
                                          style: TextStyle(
                                            color: roleColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            u.displayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            '@${u.username}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Role / Access
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: roleColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(roleIcon, size: 14, color: roleColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          u.roleLabel.isNotEmpty ? u.roleLabel : u.role,
                                          style: TextStyle(
                                            color: roleColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Contact
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u.email ?? '—',
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                      ),
                                      if (u.phone != null && u.phone!.isNotEmpty)
                                        Text(
                                          u.phone!,
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                    ],
                                  ),
                                ),

                                // Status
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: u.isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        u.isActive ? 'Active' : 'Disabled',
                                        style: TextStyle(
                                          color: u.isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Actions
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit Profile & Role',
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        color: const Color(0xFF0F766E),
                                        onPressed: () => _showEditUserDialog(u),
                                      ),
                                      IconButton(
                                        tooltip: 'Reset Password',
                                        icon: const Icon(Icons.lock_reset, size: 18),
                                        color: const Color(0xFFD97706),
                                        onPressed: () => _showResetPasswordDialog(u),
                                      ),
                                      IconButton(
                                        tooltip: u.isActive ? 'Deactivate User' : 'Activate User',
                                        icon: Icon(
                                          u.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                                          size: 18,
                                        ),
                                        color: u.isActive ? Colors.red.shade600 : const Color(0xFF16A34A),
                                        onPressed: () => ref
                                            .read(usersControllerProvider.notifier)
                                            .toggleUserStatus(u.id, u.isActive),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
