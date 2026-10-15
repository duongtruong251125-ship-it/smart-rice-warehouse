import 'package:smart_rice_warehouse/providers/theme_provider.dart';
import 'package:smart_rice_warehouse/core/services/settings_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/models/user_model.dart';
import 'package:smart_rice_warehouse/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/widgets/confirmation_dialog.dart';
import 'package:smart_rice_warehouse/core/services/image_storage_service.dart';

/// Màn hình Tài khoản - Tái cấu trúc theo phong cách "AgriWarehouse Modern System"
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  void _showPasswordModal(BuildContext context) {
    final rootContext = context;
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Đổi mật khẩu',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.dangerBorder),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                              color: AppTheme.dangerText, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu hiện tại',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu mới',
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu mới',
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        final current = currentPasswordController.text.trim();
                        final newPass = newPasswordController.text.trim();
                        final confirm = confirmPasswordController.text.trim();

                        if (current.isEmpty ||
                            newPass.isEmpty ||
                            confirm.isEmpty) {
                          setState(() {
                            errorMessage =
                                'Vui lòng nhập đầy đủ các trường mật khẩu';
                          });
                          return;
                        }
                        if (newPass.length < 6) {
                          setState(() {
                            errorMessage =
                                'Mật khẩu mới phải có ít nhất 6 ký tự';
                          });
                          return;
                        }
                        if (newPass != confirm) {
                          setState(() {
                            errorMessage = 'Mật khẩu xác nhận không khớp';
                          });
                          return;
                        }

                        final changed = bottomSheetContext
                            .read<AuthProvider>()
                            .changePassword(
                              current: current,
                              replacement: newPass,
                            );
                        if (!changed) {
                          setState(() {
                            errorMessage = 'Mật khẩu hiện tại không chính xác';
                          });
                          return;
                        }
                        Navigator.pop(bottomSheetContext);
                        AppToast.success(
                          rootContext,
                          'Đổi mật khẩu thành công!',
                        );
                      },
                      child: const Text(
                        'Xác nhận đổi',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  void _showSettingsModal(BuildContext context) {
    final rootContext = context;
    final themeProvider = context.read<ThemeProvider>();
    final settings = context.read<SettingsService>();
    bool isDarkMode = themeProvider.isDarkMode;
    bool pushNotifications = settings.pushNotifications;
    bool syncData = settings.backgroundSync;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Cài đặt hệ thống',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text(
                        'Chế độ Nền tối (Dark Mode)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: const Text(
                        'Giao diện tối giúp dịu mắt hơn',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: isDarkMode,
                      activeTrackColor: AppTheme.primaryLight,
                      activeThumbColor: AppTheme.primaryColor,
                      secondary: const Icon(Icons.dark_mode_rounded),
                      onChanged: (val) {
                        setState(() => isDarkMode = val);
                        themeProvider.toggleTheme(val);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text(
                        'Thông báo Đẩy (Push)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: const Text(
                        'Nhận cảnh báo hạn sử dụng, tồn kho',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: pushNotifications,
                      activeTrackColor: AppTheme.primaryLight,
                      activeThumbColor: AppTheme.primaryColor,
                      secondary: const Icon(Icons.notifications_active_rounded),
                      onChanged: (val) =>
                          setState(() => pushNotifications = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text(
                        'Đồng bộ dữ liệu nền',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: const Text(
                        'Tự động tải số liệu mới nhất',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: syncData,
                      activeTrackColor: AppTheme.primaryLight,
                      activeThumbColor: AppTheme.primaryColor,
                      secondary: const Icon(Icons.sync_rounded),
                      onChanged: (val) => setState(() => syncData = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        await settings.setPushNotifications(pushNotifications);
                        await settings.setBackgroundSync(syncData);
                        if (!bottomSheetContext.mounted) return;
                        Navigator.pop(bottomSheetContext);
                        AppToast.success(
                          rootContext,
                          'Đã lưu cấu hình cài đặt!',
                        );
                      },
                      child: const Text(
                        'Lưu cấu hình',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
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
    final rootContext = context;
    File? selectedImage;
    final picker = ImagePicker();
    final nameController =
        TextEditingController(text: user?.name ?? 'Admin Quản Lý');
    final roleController = TextEditingController(text: _roleLabel(user?.role));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Cập nhật Hồ sơ',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final pickedFile = await picker.pickImage(
                              source: ImageSource.gallery);
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
                              backgroundImage: selectedImage != null
                                  ? FileImage(selectedImage!)
                                  : null,
                              child: selectedImage == null
                                  ? const Icon(Icons.person,
                                      size: 40, color: AppTheme.primaryColor)
                                  : null,
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                color: AppTheme.secondaryColor,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: roleController,
                      decoration: const InputDecoration(
                        labelText: 'Chức vụ',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        String? permanentAvatarPath = user?.avatarPath;
                        if (selectedImage != null) {
                          permanentAvatarPath =
                              await ImageStorageService.saveImagePermanently(
                            selectedImage!.path,
                            subDirectory: 'avatars',
                            oldPathToDelete: user?.avatarPath,
                          );
                        }
                        final updated =
                            rootContext.read<AuthProvider>().updateProfile(
                                  name: nameController.text,
                                  role: roleController.text,
                                  avatarPath: permanentAvatarPath,
                                );
                        if (!updated) {
                          AppToast.error(
                            rootContext,
                            'Họ tên và chức vụ không được để trống',
                          );
                          return;
                        }
                        if (bottomSheetContext.mounted) {
                          Navigator.pop(bottomSheetContext);
                        }
                        AppToast.success(
                          rootContext,
                          'Đã cập nhật hồ sơ và ảnh đại diện!',
                        );
                      },
                      child: const Text(
                        'Lưu thông tin',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      roleController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final avatarPath = user?.avatarPath;
    final avatarFile = avatarPath == null ? null : File(avatarPath);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // --- 1. USER PROFILE HERO BANNER ĐỒNG BỘ DNA DESIGN ---
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.heroEmeraldGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.modernElevation,
          ),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: avatarFile != null && avatarFile.existsSync()
                    ? ClipOval(
                        child: Image.file(
                          avatarFile,
                          fit: BoxFit.cover,
                          width: 76,
                          height: 76,
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        size: 42,
                        color: AppTheme.primaryDark,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                user?.name ?? 'Admin Quản Lý',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                user?.email ?? 'admin@smartrice.vn',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _roleLabel(user?.role),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms),

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
                Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).dividerColor),
                _ProfileOptionTile(
                  icon: Icons.lock_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: 'Đổi mật khẩu',
                  subtitle: 'Thay đổi mật khẩu an toàn',
                  onTap: () => _showPasswordModal(context),
                ),
                Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).dividerColor),
                _ProfileOptionTile(
                  icon: Icons.tune_rounded,
                  iconColor: AppTheme.accentTeal,
                  title: 'Cài đặt hệ thống',
                  subtitle: 'Giao diện & Thông báo',
                  onTap: () => _showSettingsModal(context),
                ),
                Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).dividerColor),
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
                child: const Icon(
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
                    const SizedBox(height: 2),
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
            color: isDestructive
                ? AppTheme.dangerColor
                : Theme.of(context).colorScheme.onSurface,
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
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
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

String _roleLabel(String? role) {
  return role == 'admin' ? 'Quản trị viên kho' : (role ?? 'Nhân viên vận hành');
}
