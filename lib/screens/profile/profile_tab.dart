import 'package:smart_rice_warehouse/providers/theme_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/models/user_model.dart';
import 'package:smart_rice_warehouse/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/widgets/confirmation_dialog.dart';
import 'package:smart_rice_warehouse/widgets/status_chip.dart';

/// Màn hình Tài khoản - Tái cấu trúc theo phong cách "AgriWarehouse Modern System"
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

    void _showPasswordModal(BuildContext context) {
    bool obscureCurrent = true;
    bool obscureNew = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 16),
                  const Center(child: Text('Đổi mật khẩu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 20),
                  TextField(
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đổi mật khẩu thành công!')),
                        );
                      },
                      child: Text('Xác nhận đổi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSettingsModal(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    bool isDarkMode = themeProvider.isDarkMode;
    bool pushNotifications = true;
    bool syncData = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 16),
                  const Center(child: Text('Cài đặt hệ thống', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: Text('Chế độ Nền tối (Dark Mode)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text('Giao diện tối giúp dịu mắt hơn', style: TextStyle(fontSize: 12)),
                    value: isDarkMode,
                    activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                    activeColor: AppTheme.primaryColor,
                    secondary: Icon(Icons.dark_mode_rounded),
                    onChanged: (val) {
                      setState(() => isDarkMode = val);
                      themeProvider.toggleTheme(val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  Divider(),
                  SwitchListTile(
                    title: Text('Thông báo Đẩy (Push)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text('Nhận cảnh báo hạn sử dụng, tồn kho', style: TextStyle(fontSize: 12)),
                    value: pushNotifications,
                    activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                    activeColor: AppTheme.primaryColor,
                    secondary: Icon(Icons.notifications_active_rounded),
                    onChanged: (val) => setState(() => pushNotifications = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  Divider(),
                  SwitchListTile(
                    title: Text('Đồng bộ dữ liệu nền', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text('Tự động tải số liệu mới nhất', style: TextStyle(fontSize: 12)),
                    value: syncData,
                    activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                    activeColor: AppTheme.primaryColor,
                    secondary: Icon(Icons.sync_rounded),
                    onChanged: (val) => setState(() => syncData = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã lưu cấu hình cài đặt!')),
                        );
                      },
                      child: Text('Lưu thông tin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Đăng xuất',
      message: 'Bạn có chắc muốn đăng xuất không?',
      confirmLabel: 'Đăng xuất',
    );
    if (!context.mounted || !confirmed) {
      return;
    }

    context.read<AuthProvider>().logout();
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

    void _showPersonalInformation(BuildContext context, UserModel? user) {
    File? selectedImage;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 16),
                  const Center(child: Text('Cập nhật Hồ sơ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        setState(() {
                          selectedImage = File(pickedFile.path);
                        });
                      }
                    },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppTheme.primaryLight,
                          backgroundImage: selectedImage != null ? FileImage(selectedImage!) : null,
                          child: selectedImage == null ? Icon(Icons.person, size: 40, color: AppTheme.primaryColor) : null,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Họ và tên',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    controller: TextEditingController(text: user?.name ?? 'Admin Quản Lý'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Chức vụ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    controller: TextEditingController(text: _roleLabel(user?.role)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã cập nhật hồ sơ và ảnh đại diện!')),
                        );
                      },
                      child: Text('Lưu thông tin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }



    @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // --- 1. USER PROFILE BENTO HERO CARD ---
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Avatar with soft ring
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    width: 2.5,
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 42,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                user?.name ?? 'Admin Quản Lý',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? 'admin@smartrice.vn',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              StatusChip.safe(
                label: _roleLabel(user?.role),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

                // --- 2. SETTINGS & ACTIONS CARD ---
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                _ProfileOptionTile(
                  icon: Icons.person_rounded,
                  iconColor: AppTheme.primaryColor,
                  title: 'Thông tin cá nhân',
                  subtitle: 'Cập nhật avatar, họ tên',
                  onTap: () => _showPersonalInformation(context, user),
                ),
                Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
                _ProfileOptionTile(
                  icon: Icons.lock_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: 'Đổi mật khẩu',
                  subtitle: 'Thay đổi mật khẩu an toàn',
                  onTap: () => _showPasswordModal(context),
                ),
                Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
                _ProfileOptionTile(
                  icon: Icons.tune_rounded,
                  iconColor: AppTheme.accentTeal,
                  title: 'Cài đặt hệ thống',
                  subtitle: 'Giao diện & Thông báo',
                  onTap: () => _showSettingsModal(context),
                ),
                Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
                _ProfileOptionTile(
                  icon: Icons.logout_rounded,
                  iconColor: const Color(0xFFDC2626),
                  title: 'Đăng xuất',
                  subtitle: 'Thoát phiên làm việc trên thiết bị này',
                  isDestructive: true,
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
        ),



        // --- 3. SYSTEM FOOTER BRANDING ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Rice Warehouse • AgriSystem',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hệ thống Quản lý & Giám sát Kho lúa gạo hiện đại',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileOptionTile extends StatelessWidget {
  const _ProfileOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color:
                isDestructive ? const Color(0xFFDC2626) : AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

String _roleLabel(String? role) {
  return role == 'admin' ? 'Quản trị viên kho' : (role ?? 'Nhân viên vận hành');
}
