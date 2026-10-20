import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/presentation/routes/app_routes.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/logic/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/logic/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/logic/view_models/warehouse_hub_view_model.dart';
import 'package:smart_rice_warehouse/presentation/widgets/pressable_scale.dart';

/// =======================================================================
/// TAB 2: HUB KHO HÀNG (WAREHOUSE HUB)
/// Đồng bộ 100% với layout của HomeTab:
/// - Hero Banner Emerald Gradient cao cấp với KPI chips & phím tắt nhanh.
/// - Thẻ Tình trạng Sức chứa Silo & Vị trí Kệ.
/// - Nhóm chức năng Bento Cards phân cấp trực quan, responsive 320px+.
/// =======================================================================
class WarehouseHub extends StatelessWidget {
  const WarehouseHub({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = WarehouseHubViewModel(
      warehouseProvider: context.watch<WarehouseProvider>(),
      batchProvider: context.watch<BatchProvider>(),
      riceProvider: context.watch<RiceProvider>(),
      supplierProvider: context.watch<SupplierProvider>(),
      customerProvider: context.watch<CustomerProvider>(),
      damageProvider: context.watch<DamageProvider>(),
    );

    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget maybeFadeIn(Widget child, Duration duration) {
      if (disableAnimations) return child;
      return child.animate().fadeIn(duration: duration);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // --- TẦNG 1: HERO BANNER ĐỒNG BỘ DNA DESIGN ---
        maybeFadeIn(
          _WarehouseHeroBanner(
            locationCount: vm.locationCount,
            batchCount: vm.batchCount,
            totalTons: vm.totalTons,
            onScanQr: () =>
                Navigator.of(context).pushNamed(AppRoutes.qrScanner),
            onInventoryCheck: () =>
                Navigator.of(context).pushNamed(AppRoutes.inventoryCheck),
          ),
          250.ms,
        ),

        const SizedBox(height: 18),

        // --- TẦNG 2: THẺ TỒN KHO & TIẾN ĐỘ SỨC CHỨA SILO ---
        maybeFadeIn(
          _WarehouseCapacityCard(
            totalTons: vm.totalTons,
            totalBags: vm.totalBags,
            capacityPercent: vm.capacityPercent,
            locationCount: vm.locationCount,
            onViewLocations: () =>
                Navigator.of(context).pushNamed(AppRoutes.warehouseLocations),
          ),
          300.ms,
        ),

        const SizedBox(height: 20),

        // --- TẦNG 3: NHÓM CHỨC NĂNG VẬN HÀNH HIỆN TRƯỜNG ---
        _buildSectionHeader('Vận hành Hiện trường & Kiểm soát', context),
        const SizedBox(height: 10),
        _HubItemCard(
          title: 'Sơ đồ vị trí Silo & Kệ',
          badgeText: '${vm.locationCount} vị trí',
          badgeColor: const Color(0xFFD97706),
          icon: Icons.grid_view_rounded,
          iconBgColor: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          route: AppRoutes.warehouseLocations,
        ),
        const SizedBox(height: 8),
        _HubItemCard(
          title: 'Báo hỏng & Hao hụt gạo',
          badgeText: '${vm.damageReportCount} phiếu',
          badgeColor: const Color(0xFFDC2626),
          icon: Icons.warning_amber_rounded,
          iconBgColor: const Color(0xFFFEE2E2),
          iconColor: const Color(0xFFDC2626),
          route: AppRoutes.damageReportList,
        ),

        const SizedBox(height: 20),

        // --- TẦNG 4: QUẢN TRỊ DANH MỤC & LÔ HÀNG ---
        _buildSectionHeader('Quản trị Danh mục & Lô hàng', context),
        const SizedBox(height: 10),
        _HubItemCard(
          title: 'Tồn kho khả dụng',
          badgeText: '${vm.totalTons.toStringAsFixed(1)} Tấn',
          badgeColor: AppTheme.primaryColor,
          icon: Icons.inventory_2_outlined,
          iconBgColor: AppTheme.primaryLight,
          iconColor: AppTheme.primaryColor,
          route: AppRoutes.inventory,
        ),
        const SizedBox(height: 8),
        _HubItemCard(
          title: 'Quản lý Lô gạo (Batches)',
          badgeText: '${vm.batchCount} lô',
          badgeColor: const Color(0xFF0F766E),
          icon: Icons.layers_outlined,
          iconBgColor: const Color(0xFFCCFBF1),
          iconColor: const Color(0xFF0F766E),
          route: AppRoutes.batches,
        ),
        const SizedBox(height: 8),
        _HubItemCard(
          title: 'Danh mục Giống gạo',
          badgeText: '${vm.riceCount} giống gạo',
          badgeColor: const Color(0xFF2563EB),
          icon: Icons.rice_bowl_outlined,
          iconBgColor: const Color(0xFFDBEAFE),
          iconColor: const Color(0xFF2563EB),
          route: AppRoutes.rice,
        ),

        const SizedBox(height: 20),

        // --- TẦNG 5: ĐỐI TÁC CHUỖI CUNG ỨNG ---
        _buildSectionHeader('Đối tác Chuỗi cung ứng', context),
        const SizedBox(height: 10),
        _HubItemCard(
          title: 'Nhà cung cấp lúa gạo',
          badgeText: '${vm.supplierCount} đối tác',
          badgeColor: const Color(0xFFD97706),
          icon: Icons.local_shipping_outlined,
          iconBgColor: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          route: AppRoutes.suppliers,
        ),
        const SizedBox(height: 8),
        _HubItemCard(
          title: 'Khách hàng & Đại lý',
          badgeText: '${vm.customerCount} đại lý',
          badgeColor: const Color(0xFF7C3AED),
          icon: Icons.store_mall_directory_outlined,
          iconBgColor: const Color(0xFFEDE9FE),
          iconColor: const Color(0xFF7C3AED),
          route: AppRoutes.customers,
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
/// WIDGET 1: HERO BANNER HUB KHO HÀNG (ĐỒNG BỘ MÀU EMERALD GRADIENT)
/// -----------------------------------------------------------------------
class _WarehouseHeroBanner extends StatelessWidget {
  const _WarehouseHeroBanner({
    required this.locationCount,
    required this.batchCount,
    required this.totalTons,
    required this.onScanQr,
    required this.onInventoryCheck,
  });

  final int locationCount;
  final int batchCount;
  final double totalTons;
  final VoidCallback onScanQr;
  final VoidCallback onInventoryCheck;

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
          const Text(
            'TRUNG TÂM VẬN HÀNH KHO GẠO',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hệ thống Vị trí Silo & Quản lý Lô Hàng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          // Chips thông số nhanh
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildMiniChip('$locationCount Kệ Silo'),
              _buildMiniChip('$batchCount Lô hàng'),
              _buildMiniChip('~${totalTons.toStringAsFixed(1)} Tấn'),
            ],
          ),
          const SizedBox(height: 14),
          // 2 nút tác vụ nhanh trên banner
          Row(
            children: [
              Expanded(
                child: _BannerButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Quét QR Lô',
                  onTap: onScanQr,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BannerButton(
                  icon: Icons.fact_check_rounded,
                  label: 'Kiểm kê kho',
                  onTap: onInventoryCheck,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({
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
      semanticLabel: label,
      onTap: onTap,
      scaleFactor: 0.95,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isDark ? Border.all(color: AppTheme.darkBorder) : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isDark ? const Color(0xFF34D399) : AppTheme.primaryDark,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark ? const Color(0xFF34D399) : AppTheme.primaryDark,
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
/// WIDGET 2: THẺ SỨC CHỨA SILO & VỊ TRÍ KHO
/// -----------------------------------------------------------------------
class _WarehouseCapacityCard extends StatelessWidget {
  const _WarehouseCapacityCard({
    required this.totalTons,
    required this.totalBags,
    required this.capacityPercent,
    required this.locationCount,
    required this.onViewLocations,
  });

  final double totalTons;
  final int totalBags;
  final double capacityPercent;
  final int locationCount;
  final VoidCallback onViewLocations;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final primaryAccent =
        isDark ? const Color(0xFF34D399) : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border(context),
        ),
        boxShadow: isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warehouse_rounded, size: 18, color: primaryAccent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Sức chứa Kho & Vị trí Kệ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onViewLocations,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sơ đồ kệ',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: primaryAccent,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: primaryAccent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    totalTons.toStringAsFixed(1),
                    style: AppTheme.tabularFigures(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  Text(
                    'Tấn',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                  Text(
                    '(~$totalBags bao)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkBackground
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Text(
                  'Lấp đầy: ${(capacityPercent * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: capacityPercent,
              minHeight: 7,
              backgroundColor:
                  isDark ? const Color(0xFF131D31) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                capacityPercent > 0.85
                    ? (isDark ? const Color(0xFFF87171) : AppTheme.dangerColor)
                    : primaryAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// -----------------------------------------------------------------------
/// WIDGET 3: CARD MỤC CHỨC NĂNG (HUB ITEM CARD ĐỒNG BỘ)
/// -----------------------------------------------------------------------
class _HubItemCard extends StatelessWidget {
  const _HubItemCard({
    required this.title,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.route,
  });

  final String title;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String route;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return PressableScale(
      semanticLabel: '$title, $badgeText',
      onTap: () => Navigator.of(context).pushNamed(route),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
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
