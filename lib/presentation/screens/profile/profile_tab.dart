import 'package:smart_rice_warehouse/presentation/theme/theme_provider.dart';
import 'package:smart_rice_warehouse/logic/contracts/app_settings.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/utils/app_toast.dart';
import 'package:smart_rice_warehouse/logic/models/sync_status_model.dart';
import 'package:smart_rice_warehouse/logic/models/user_model.dart';
import 'package:smart_rice_warehouse/logic/providers/auth_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/export_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/import_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/presentation/screens/profile/profile_modals.dart';
import 'package:smart_rice_warehouse/presentation/widgets/async_status_banner.dart';
import 'package:smart_rice_warehouse/presentation/widgets/confirmation_dialog.dart';
import 'package:smart_rice_warehouse/presentation/widgets/pressable_scale.dart';
import 'package:smart_rice_warehouse/logic/view_models/profile_view_model.dart';

/// Màn hình Tài khoản - Tái cấu trúc theo phong cách "AgriWarehouse Modern System"
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _migrateLegacy(BuildContext context, AuthProvider auth) async {
    final confirmed = await showConfirmationDialog(
        context: context,
        title: 'Dùng dữ liệu cũ làm dữ liệu thật?',
        message:
            'Chuyển dữ liệu SQLite cũ lên cloud. Giữ nguyên bản gốc và mọi bản ghi cloud đã có. Số dư lô chỉ ghi nhận một lần, không cộng lại lịch sử phiếu.',
        confirmLabel: 'Xác nhận chuyển');
    if (!confirmed || !context.mounted) return;
    final result = await auth.migrateLegacyData();
    if (!context.mounted) return;
    if (result.success) {
      AppToast.success(context, result.message ?? 'Đã chuyển dữ liệu.');
    } else {
      AppToast.error(
          context, result.message ?? 'Chưa hoàn tất. Có thể thử lại.');
    }
  }

  void _showPasswordModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ChangePasswordSheet(),
    );
  }

  void _showSettingsModal(BuildContext context) {
    final rootContext = context;
    final themeProvider = context.read<ThemeProvider>();
    final settings = context.read<AppSettings>();
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
                        'Cập nhật dữ liệu khi ứng dụng ở nền. Tắt không đổi backend; giao dịch cloud vẫn cần mạng.',
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
                          'Đã lưu. Đồng bộ nền có hiệu lực ngay; backend không thay đổi.',
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

    await context.read<AuthProvider>().logoutWithFirebase();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  void _showPersonalInformation(BuildContext context, UserModel? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PersonalInformationSheet(user: user),
    );
  }

  void _showUserManagementModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const UserManagementSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isAdmin = auth.isAdmin;
    final avatarPath = user?.avatarPath;
    final avatarFile = avatarPath == null ? null : File(avatarPath);
    final isDark = AppTheme.isDark(context);

    final rices = context.watch<RiceProvider?>();
    final batches = context.watch<BatchProvider?>();
    final imports = context.watch<ImportProvider?>();
    final exports = context.watch<ExportProvider?>();
    final syncStatus = ProfileViewModel.resolveSyncStatus(
      rices: rices,
      batches: batches,
      imports: imports,
      exports: exports,
      backgroundSyncEnabled: context.watch<AppSettings?>()?.backgroundSync,
    );

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // --- TẦNG 1: HERO BANNER TÀI KHOẢN ĐỒNG BỘ DNA DESIGN ---
        _ProfileHeroBanner(
          user: user,
          isAdmin: isAdmin,
          avatarFile: avatarFile,
          syncStatus: syncStatus,
          onRetrySync: () => ProfileViewModel.retrySync(
            rices: rices,
            batches: batches,
            imports: imports,
            exports: exports,
          ),
          onEditProfile: () => _showPersonalInformation(context, user),
          onOpenSettings: () => _showSettingsModal(context),
        ).animate().fadeIn(duration: 250.ms),

        const SizedBox(height: 18),

        // --- TẦNG 2: HỒ SƠ & CẤU HÌNH HỆ THỐNG (HUB CARDS) ---
        _buildSectionHeader('Thiết lập Hồ sơ & Bảo mật', context),
        const SizedBox(height: 10),
        _ProfileHubCard(
          title: 'Thông tin cá nhân',
          badgeText: 'Hồ sơ',
          badgeColor: AppTheme.primaryColor,
          icon: Icons.person_rounded,
          iconBgColor: AppTheme.primaryLight,
          iconColor: AppTheme.primaryColor,
          onTap: () => _showPersonalInformation(context, user),
        ),
        const SizedBox(height: 8),
        _ProfileHubCard(
          title: 'Đổi mật khẩu',
          badgeText: 'Bảo mật',
          badgeColor: const Color(0xFFD97706),
          icon: Icons.lock_rounded,
          iconBgColor: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          onTap: () => _showPasswordModal(context),
        ),
        const SizedBox(height: 8),
        _ProfileHubCard(
          title: 'Cài đặt hệ thống',
          badgeText: 'Tùy chỉnh',
          badgeColor: AppTheme.accentTeal,
          icon: Icons.tune_rounded,
          iconBgColor: const Color(0xFFCCFBF1),
          iconColor: AppTheme.accentTeal,
          onTap: () => _showSettingsModal(context),
        ),

        if (isAdmin) ...[
          if (auth.canMigrateLegacy) ...[
            const SizedBox(height: 8),
            _ProfileHubCard(
              title: auth.isMigratingLegacy
                  ? 'Đang chuyển dữ liệu cũ...'
                  : 'Dùng dữ liệu cũ làm dữ liệu thật',
              badgeText: 'Admin',
              badgeColor: AppTheme.primaryColor,
              icon: Icons.cloud_upload_rounded,
              iconBgColor: AppTheme.primaryLight,
              iconColor: AppTheme.primaryColor,
              onTap: () {
                if (!auth.isMigratingLegacy) _migrateLegacy(context, auth);
              },
            ),
          ],
          const SizedBox(height: 8),
          _ProfileHubCard(
            title: 'Quản lý nhân sự & Phân quyền',
            badgeText: '${auth.managedUsers.length} nhân sự',
            badgeColor: const Color(0xFF2563EB),
            icon: Icons.manage_accounts_rounded,
            iconBgColor: const Color(0xFFDBEAFE),
            iconColor: const Color(0xFF2563EB),
            onTap: () => _showUserManagementModal(context),
          ),
        ],

        const SizedBox(height: 8),
        _ProfileHubCard(
          title: 'Đăng xuất',
          badgeText: 'Thoát phiên',
          badgeColor: const Color(0xFFDC2626),
          icon: Icons.logout_rounded,
          iconBgColor: const Color(0xFFFEE2E2),
          iconColor: const Color(0xFFDC2626),
          isDestructive: true,
          onTap: () => _logout(context),
        ),

        const SizedBox(height: 18),

        // --- TẦNG 3: SYSTEM FOOTER BRANDING ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
            boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.primaryColor.withValues(alpha: 0.18)
                      : AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 19,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Rice Warehouse • AgriSystem',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hệ thống Quản lý & Giám sát Kho lúa gạo Real-time',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondaryColor(context),
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

  static Widget _buildSectionHeader(String title, BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimaryColor(context),
        letterSpacing: -0.2,
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 1: HERO BANNER TÀI KHOẢN (ĐỒNG BỘ EMERALD GRADIENT VỚI HOME/HUB)
/// -----------------------------------------------------------------------
class _ProfileHeroBanner extends StatelessWidget {
  const _ProfileHeroBanner({
    required this.user,
    required this.isAdmin,
    required this.avatarFile,
    required this.syncStatus,
    required this.onRetrySync,
    required this.onEditProfile,
    required this.onOpenSettings,
  });

  final UserModel? user;
  final bool isAdmin;
  final File? avatarFile;
  final WarehouseSyncStatus syncStatus;
  final VoidCallback onRetrySync;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.modernElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TRUNG TÂM TÀI KHOẢN & BẢO MẬT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAdmin ? 'Quản trị kho' : 'Vận hành kho',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: onEditProfile,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: avatarFile != null && avatarFile!.existsSync()
                      ? ClipOval(
                          child: Image.file(
                            avatarFile!,
                            fit: BoxFit.cover,
                            width: 58,
                            height: 58,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 32,
                          color: AppTheme.primaryDark,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Admin Quản Lý',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'admin@smartrice.vn',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildMiniChip(_roleLabel(user?.role)),
                        SyncStatusBadge(
                          status: syncStatus,
                          onRetry: onRetrySync,
                          onHeroSurface: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ProfileBannerButton(
                  icon: Icons.badge_outlined,
                  label: 'Sửa hồ sơ',
                  onTap: onEditProfile,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfileBannerButton(
                  icon: Icons.tune_rounded,
                  label: 'Cấu hình nhanh',
                  onTap: onOpenSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ProfileBannerButton extends StatelessWidget {
  const _ProfileBannerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.95,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isDark ? AppTheme.primaryColor : AppTheme.primaryDark,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isDark ? Colors.white : AppTheme.primaryDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 2: CARD CHỨC NĂNG TÀI KHOẢN (ĐỒNG BỘ HUB ITEM CARD)
/// -----------------------------------------------------------------------
class _ProfileHubCard extends StatelessWidget {
  const _ProfileHubCard({
    required this.title,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.onTap,
    this.isDestructive = false,
  });

  final String title;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.98,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.border(context),
          ),
          boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? iconColor.withValues(alpha: 0.18) : iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDestructive
                      ? AppTheme.dangerColor
                      : AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : badgeColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textSecondaryColor(context),
            ),
          ],
        ),
      ),
    );
  }
}

String _roleLabel(String? role) {
  final normalized = role?.trim().toLowerCase() ?? '';
  if (normalized == 'admin' || normalized.contains('quản trị')) {
    return 'Quản trị viên kho (Admin)';
  }
  if (normalized == 'staff' || normalized.contains('nhân viên')) {
    return 'Nhân viên vận hành kho (Staff)';
  }
  return 'Nhân viên vận hành kho';
}
