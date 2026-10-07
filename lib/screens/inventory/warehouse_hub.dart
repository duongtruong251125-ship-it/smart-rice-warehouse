import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/customer_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/providers/supplier_provider.dart';
import 'package:smart_rice_warehouse/widgets/section_title.dart';

class WarehouseHub extends StatelessWidget {
  const WarehouseHub({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final riceCount = context.watch<RiceProvider>().rices.length;
    final batchProvider = context.watch<BatchProvider>();
    final supplierCount = context.watch<SupplierProvider>().suppliers.length;
    final customerCount = context.watch<CustomerProvider>().customers.length;

    final items = <_WarehouseItem>[
      _WarehouseItem(
        title: 'Quản lý gạo',
        subtitle: 'Danh mục mặt hàng, đơn vị, giá nhập & giá bán',
        badge: '$riceCount loại',
        icon: Icons.rice_bowl_outlined,
        color: AppTheme.primaryColor,
        route: AppRoutes.rice,
      ),
      _WarehouseItem(
        title: 'Tồn kho',
        subtitle: 'Kiểm tra số lượng tồn thực tế & cảnh báo sắp hết',
        badge: '${batchProvider.totalStock.round()} kg',
        icon: Icons.inventory_outlined,
        color: AppTheme.accentBlue,
        route: AppRoutes.inventory,
      ),
      _WarehouseItem(
        title: 'Lô gạo',
        subtitle: 'Quản lý mã lô, ngày sản xuất & hạn sử dụng',
        badge: '${batchProvider.batches.length} lô',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF0D9488),
        route: AppRoutes.batches,
      ),
      _WarehouseItem(
        title: 'Nhà cung cấp',
        subtitle: 'Thông tin đối tác cung ứng lúa gạo',
        badge: '$supplierCount ĐT',
        icon: Icons.local_shipping_outlined,
        color: AppTheme.secondaryColor,
        route: AppRoutes.suppliers,
      ),
      _WarehouseItem(
        title: 'Khách hàng',
        subtitle: 'Danh bạ đại lý, tạp hóa & khách mua lẻ',
        badge: '$customerCount KH',
        icon: Icons.groups_outlined,
        color: const Color(0xFF7C3AED),
        route: AppRoutes.customers,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const SectionTitle('Danh mục quản lý kho'),
        const SizedBox(height: 12),
        for (var index = 0; index < items.length; index++) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: items[index].color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  items[index].icon,
                  color: items[index].color,
                  size: 24,
                ),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      items[index].title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: items[index].color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      items[index].badge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: items[index].color,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  items[index].subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              trailing: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ),
              onTap: () => Navigator.of(context).pushNamed(items[index].route),
            ),
          ),
          if (index < items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _WarehouseItem {
  const _WarehouseItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color color;
  final String route;
}

