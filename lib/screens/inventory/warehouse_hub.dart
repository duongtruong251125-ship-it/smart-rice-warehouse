import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/widgets/pressable_scale.dart';

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
    final riceCount = context.watch<RiceProvider>().rices.length;
    final batchProvider = context.watch<BatchProvider>();
    final supplierCount = context.watch<SupplierProvider>().suppliers.length;
    final customerCount = context.watch<CustomerProvider>().customers.length;
    final warehouseProvider = context.watch<WarehouseProvider>();
    final damageProvider = context.watch<DamageProvider>();

    final totalKg = batchProvider.totalStock;
    final totalTons = totalKg / 1000.0;
    final totalBags = (totalKg / 50.0).round();
    const double maxCapacityTons = 200.0;
    final capacityPercent = (totalTons / maxCapacityTons).clamp(0.0, 1.0);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // --- TẦNG 1: HERO BANNER ĐỒNG BỘ DNA DESIGN ---
        _WarehouseHeroBanner(
          locationCount: warehouseProvider.locations.length,
          batchCount: batchProvider.batches.length,
          totalTons: totalTons,
          onScanQr: () => Navigator.of(context).pushNamed(AppRoutes.qrScanner),
          onInventoryCheck: () => Navigator.of(context).pushNamed(AppRoutes.inventoryCheck),
        )
            .animate()
            .fadeIn(duration: 250.ms),

        const SizedBox(height: 18),

        // --- TẦNG 2: THẺ TỒN KHO & TIẾN ĐỘ SỨC CHỨA SILO ---
        _WarehouseCapacityCard(
          totalTons: totalTons,
          totalBags: totalBags,
          capacityPercent: capacityPercent,
          locationCount: warehouseProvider.locations.length,
          onViewLocations: () => Navigator.of(context).pushNamed(AppRoutes.warehouseLocations),
        )
            .animate()
            .fadeIn(duration: 300.ms),

        const SizedBox(height: 20),

        // --- TẦNG 3: NHÓM CHỨC NĂNG VẬN HÀNH HIỆN TRƯỜNG ---
        _buildSectionHeader('Vận hành Hiện trường & Kiểm soát'),
        const SizedBox(height: 10),
        _HubItemCard(
          title: 'Sơ đồ vị trí Silo & Kệ',
          subtitle: 'Bản đồ trực quan sơ đồ kho',
          badgeText: '${warehouseProvider.locations.length} vị trí',
          badgeColor: const Color(0xFFD97706),
          icon: Icons.grid_view_rounded,
          iconBgColor: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          route: AppRoutes.warehouseLocations,
        ),
        const SizedBox(height: 8),
        _HubItemCard(
          title: 'Báo hỏng & Hao hụt gạo',
          subtitle: 'Ghi nhận tỷ lệ hao hụt, mối mọt',
          badgeText: '${damageProvider.reports.length} phiếu',
          badgeColor: const Color(0xFFDC2626),
          icon: Icons.warning_amber_rounded,
          iconBgColor: const Color(0xFFFEE2E2),
          iconColor: const Color(0xFFDC2626),
          route: AppRoutes.damageReportList,
        ),

        const SizedBox(height: 20),

        // --- TẦNG 4: QUẢN TRỊ DANH MỤC & LÔ HÀNG ---
        _buildSectionHeader('Quản trị Danh mục & Lô hàng'),
        const SizedBox(height: 10),
        _HubItemCard(
          title: 'Tồn kho khả dụng',
          subtitle: 'Thẻ kho chi tiết từng loại gạo',
          badgeText: '${totalTons.toStringAsFixed(1)} Tấn',
          badgeColor: AppTheme.primaryColor,
          icon: Icons.inventory_2_outlined,
          iconBgColor: AppTheme.primaryLight,
          iconColor: AppTheme.primaryColor,
          route: AppRoutes.inventory,
        ),
        const SizedBox(height: 8),
        _HubItemCard(
          title: 'Quản lý Lô gạo (Batches)',
          subtitle: 'Hạn dùng, nguồn gốc, ngày nhập',
          badgeText: '${batchProvider.batches.length} lô',
          badgeColor: const Color(0xFF0D9488),
          icon: Icons.layers_outlined,
          iconBgColor: const Color(0xFFCCFBF1),
          iconColor: const Color(0xFF0D9488),
          route: AppRoutes.batches,
        ),
        const SizedBox(height: 8),
        _HubItemCard(
          title: 'Danh mục Giống gạo',
          subtitle: 'Giá vốn, đơn vị đo, quy cách bao',
          badgeText: '$riceCount giống gạo',
          badgeColor: const Color(0xFF2563EB),
          icon: Icons.rice_bowl_outlined,
          iconBgColor: const Color(0xFFDBEAFE),
          iconColor: const Color(0xFF2563EB),
          route: AppRoutes.rice,
        ),

        const SizedBox(height: 20),

        // --- TẦNG 5: ĐỐI TÁC CHUỖI CUNG ỨNG ---
        _buildSectionHeader('Đối tác Chuỗi cung ứng'),
        const SizedBox(height: 10),
        _HubItemCard(
          title: 'Nhà cung cấp lúa gạo',
          subtitle: 'Đối tác thu mua, thương lái, HTX',
          badgeText: '$supplierCount đối tác',
          badgeColor: const Color(0xFFD97706),
          icon: Icons.local_shipping_outlined,
          iconBgColor: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
          route: AppRoutes.suppliers,
        ),
        const SizedBox(height: 8),
        _HubItemCard(
          title: 'Khách hàng & Đại lý',
          subtitle: 'Nhà phân phối, siêu thị, nhà bán lẻ',
          badgeText: '$customerCount đại lý',
          badgeColor: const Color(0xFF7C3AED),
          icon: Icons.store_mall_directory_outlined,
          iconBgColor: const Color(0xFFEDE9FE),
          iconColor: const Color(0xFF7C3AED),
          route: AppRoutes.customers,
        ),
      ],
    );
  }

  static Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppTheme.heroEmeraldGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.modernElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TRUNG TÂM VẬN HÀNH KHO GẠO',
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Quản trị kho',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Hệ thống Vị trí Silo & Quản lý Lô Hàng',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
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
    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.95,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryDark),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warehouse_rounded, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Sức chứa Kho & Vị trí Kệ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: onViewLocations,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sơ đồ kệ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          totalTons.toStringAsFixed(1),
                          style: AppTheme.tabularFigures(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Tấn',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(~$totalBags bao)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Lấp đầy: ${(capacityPercent * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
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
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                capacityPercent > 0.85 ? AppTheme.dangerColor : AppTheme.primaryColor,
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
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String route;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => Navigator.of(context).pushNamed(route),
      scaleFactor: 0.98,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
