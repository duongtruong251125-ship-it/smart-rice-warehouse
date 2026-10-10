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

  void _showPasswordMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chức năng đang được phát triển')),
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
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 16),
                  const Text('Cập nhật Hồ sơ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          child: selectedImage == null ? const Icon(Icons.person, size: 40, color: AppTheme.primaryColor) : null,
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: AppTheme.secondaryColor,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Họ và tên',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    controller: TextEditingController(text: user?.name ?? 'Admin Quản Lý'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Chức vụ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.badge_outlined),
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
                      child: const Text('Lưu thông tin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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



  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cài đặt hệ thống',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: const Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.language_rounded,
                          color: AppTheme.primaryColor),
                      title: Text('Ngôn ngữ hiển thị',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Text(
                        'Tiếng Việt',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    ListTile(
                      leading: Icon(Icons.palette_outlined,
                          color: AppTheme.accentTeal),
                      title: Text('Chế độ giao diện',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Text(
                        'Sáng (AgriWarehouse)',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    ListTile(
                      leading: Icon(Icons.info_outline_rounded,
                          color: AppTheme.accentBlue),
                      title: Text('Phiên bản Build',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Text(
                        'v2.4.0 (Enterprise)',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
            color: Colors.white,
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
                child: const Icon(
                  Icons.person_rounded,
                  size: 42,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                user?.name ?? 'Admin Quản Lý',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? 'admin@smartrice.vn',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
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
            color: Colors.white,
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
                  icon: Icons.badge_outlined,
                  iconColor: AppTheme.primaryColor,
                  title: 'Thông tin cá nhân',
                  subtitle: 'Xem hồ sơ nhân sự & chức vụ',
                  onTap: () => _showPersonalInformation(context, user),
                ),
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                _ProfileOptionTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppTheme.secondaryColor,
                  title: 'Đổi mật khẩu bảo mật',
                  subtitle: 'Cập nhật khóa truy cập tài khoản',
                  onTap: () => _showPasswordMessage(context),
                ),
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                _ProfileOptionTile(
                  icon: Icons.tune_rounded,
                  iconColor: AppTheme.accentTeal,
                  title: 'Cài đặt hệ thống',
                  subtitle: 'Ngôn ngữ, giao diện & cấu hình kho',
                  onTap: () => _showSettings(context),
                ),
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
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

        const SizedBox(height: 20),

        // --- 3. SYSTEM FOOTER BRANDING ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
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
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Rice Warehouse • AgriSystem',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hệ thống Quản lý & Giám sát Kho lúa gạo hiện đại',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
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
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
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
          child: const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppTheme.textSecondary,
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

String _roleLabel(String? role) {
  return role == 'admin' ? 'Quản trị viên kho' : (role ?? 'Nhân viên vận hành');
}
