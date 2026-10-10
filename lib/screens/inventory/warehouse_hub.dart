import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/providers/damage_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/widgets/section_title.dart';

/// Màn hình Hub Kho hàng - Tái cấu trúc theo phong cách "AgriWarehouse Modern System"
/// Nhóm các chức năng thành 3 cụm Bento trực quan: Vận hành & QR, Quản trị hàng hóa & Lô, Đối tác cung ứng
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // --- 1. HERO KPI MINI BANNER ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warehouse_rounded,
                  color: AppTheme.primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trung tâm Vận hành Kho Gạo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${warehouseProvider.locations.length} vị trí kệ • ${batchProvider.batches.length} lô gạo • ~${totalTons.toStringAsFixed(1)} tấn ($totalBags bao)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // --- 2. VẬN HÀNH HIỆN TRƯỜNG & QR ---
        const SectionTitle('Vận hành hiện trường & Kiểm soát'),
        const SizedBox(height: 10),
        const _ModernHubTile(
          title: 'Quét mã QR Lô gạo',
          badgeText: 'Quét siêu tốc',
          badgeColor: Color(0xFF0284C7),
          icon: Icons.qr_code_scanner_rounded,
          iconBgColor: Color(0xFF0284C7),
          route: AppRoutes.qrScanner,
          isHighlight: true,
        ),
        const SizedBox(height: 10),
        _ModernHubTile(
          title: 'Sơ đồ vị trí Silo & Kệ',
          badgeText: '${warehouseProvider.locations.length} vị trí',
          badgeColor: const Color(0xFFD97706),
          icon: Icons.grid_view_rounded,
          iconBgColor: const Color(0xFFD97706),
          route: AppRoutes.warehouseLocations,
        ),
        const SizedBox(height: 10),
        const _ModernHubTile(
          title: 'Kiểm kê định kỳ kho',
          badgeText: 'Kiểm kê QR',
          badgeColor: AppTheme.primaryColor,
          icon: Icons.fact_check_outlined,
          iconBgColor: AppTheme.primaryColor,
          route: AppRoutes.inventoryCheck,
        ),
        const SizedBox(height: 10),
        _ModernHubTile(
          title: 'Báo hỏng & Hao hụt gạo',
          badgeText: '${damageProvider.reports.length} phiếu',
          badgeColor: const Color(0xFFDC2626),
          icon: Icons.warning_amber_rounded,
          iconBgColor: const Color(0xFFDC2626),
          route: AppRoutes.damageReportList,
        ),

        const SizedBox(height: 24),

        // --- 3. QUẢN TRỊ DANH MỤC & TỒN KHO ---
        const SectionTitle('Quản trị Danh mục & Lô hàng'),
        const SizedBox(height: 10),
        _ModernHubTile(
          title: 'Tồn kho khả dụng',
          badgeText: '${totalTons.toStringAsFixed(1)} Tấn',
          badgeColor: AppTheme.accentBlue,
          icon: Icons.inventory_outlined,
          iconBgColor: AppTheme.accentBlue,
          route: AppRoutes.inventory,
        ),
        const SizedBox(height: 10),
        _ModernHubTile(
          title: 'Quản lý Lô gạo (Batches)',
          badgeText: '${batchProvider.batches.length} lô',
          badgeColor: const Color(0xFF0D9488),
          icon: Icons.inventory_2_outlined,
          iconBgColor: const Color(0xFF0D9488),
          route: AppRoutes.batches,
        ),
        const SizedBox(height: 10),
        _ModernHubTile(
          title: 'Danh mục Loại gạo',
          badgeText: '$riceCount giống gạo',
          badgeColor: AppTheme.primaryColor,
          icon: Icons.rice_bowl_outlined,
          iconBgColor: AppTheme.primaryColor,
          route: AppRoutes.rice,
        ),

        const SizedBox(height: 24),

        // --- 4. ĐỐI TÁC CHUỖI CUNG ỨNG ---
        const SectionTitle('Đối tác Chuỗi cung ứng'),
        const SizedBox(height: 10),
        _ModernHubTile(
          title: 'Nhà cung cấp lúa gạo',
          badgeText: '$supplierCount đối tác',
          badgeColor: AppTheme.secondaryColor,
          icon: Icons.local_shipping_outlined,
          iconBgColor: AppTheme.secondaryColor,
          route: AppRoutes.suppliers,
        ),
        const SizedBox(height: 10),
        _ModernHubTile(
          title: 'Khách hàng & Đại lý',
          badgeText: '$customerCount đại lý',
          badgeColor: const Color(0xFF7C3AED),
          icon: Icons.store_mall_directory_outlined,
          iconBgColor: const Color(0xFF7C3AED),
          route: AppRoutes.customers,
        ),
      ],
    );
  }
}

class _ModernHubTile extends StatelessWidget {
  const _ModernHubTile({
    required this.title,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.iconBgColor,
    required this.route,
    this.isHighlight = false,
  });

  final String title;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color iconBgColor;
  final String route;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlight
              ? iconBgColor.withValues(alpha: 0.35)
              : AppTheme.borderColor,
          width: isHighlight ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).pushNamed(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconBgColor, size: 20),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
