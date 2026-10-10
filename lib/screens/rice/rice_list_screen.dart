import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/currency_formatter.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/widgets/confirmation_dialog.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';
import 'package:smart_rice_warehouse/widgets/search_field.dart';
import 'package:smart_rice_warehouse/widgets/status_chip.dart';

class RiceListScreen extends StatefulWidget {
  const RiceListScreen({super.key});

  @override
  State<RiceListScreen> createState() => _RiceListScreenState();
}

class _RiceListScreenState extends State<RiceListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddRice() async {
    final message = await Navigator.of(context).pushNamed(AppRoutes.addRice);
    if (!mounted || message is! String) {
      return;
    }
    _showMessage(message);
  }

  Future<void> _openEditRice(RiceModel rice) async {
    final message = await Navigator.of(context).pushNamed(
      AppRoutes.editRice,
      arguments: rice.id,
    );
    if (!mounted || message is! String) {
      return;
    }
    _showMessage(message);
  }

  Future<void> _deleteRice(RiceModel rice) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Xóa loại gạo',
      message: 'Bạn có chắc muốn xóa ${rice.name} không?',
    );
    if (!mounted || !confirmed) {
      return;
    }

    final batchProvider = context.read<BatchProvider>();
    final deleted = context.read<RiceProvider>().deleteRice(
          rice.id,
          isReferenced: (id) => batchProvider.batches.any(
            (batch) => batch.riceId == id,
          ),
        );
    if (deleted) {
      _showMessage('Đã xóa gạo');
    } else {
      _showMessage('Không thể xóa: loại gạo đang được sử dụng trong lô hàng.');
    }
  }

  void _showMessage(String message) {
    if (message.startsWith('Không')) {
      AppToast.error(context, message);
    } else {
      AppToast.success(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final riceProvider = context.watch<RiceProvider>();
    final filteredRices = riceProvider.searchRice(_query);
    final hasSearchQuery = _query.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý gạo')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchField(
                  controller: _searchController,
                  hintText: 'Tìm theo tên, mã hoặc loại gạo',
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.rice_bowl_outlined,
                      size: 15,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Danh mục: ${filteredRices.length} mặt hàng gạo',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredRices.isEmpty
                ? EmptyState(
                    icon: Icons.rice_bowl_outlined,
                    message: hasSearchQuery
                        ? 'Không tìm thấy gạo phù hợp'
                        : 'Chưa có loại gạo nào',
                    actionLabel: hasSearchQuery ? null : 'Thêm gạo',
                    onAction: hasSearchQuery ? null : _openAddRice,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: filteredRices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final rice = filteredRices[index];
                      return _RiceCard(
                        rice: rice,
                        onEdit: () => _openEditRice(rice),
                        onDelete: () => _deleteRice(rice),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddRice,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm gạo'),
      ),
    );
  }
}

class _RiceCard extends StatelessWidget {
  const _RiceCard({
    required this.rice,
    required this.onEdit,
    required this.onDelete,
  });

  final RiceModel rice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.rice_bowl_rounded,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rice.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${rice.code} • ${rice.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Đơn vị: ${rice.unit}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _PriceLabel(
                    label: 'Giá nhập',
                    value: CurrencyFormatter.formatVnd(rice.purchasePrice),
                    valueColor: AppTheme.textPrimary,
                  ),
                  _PriceLabel(
                    label: 'Giá bán',
                    value: CurrencyFormatter.formatVnd(rice.sellingPrice),
                    valueColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusChip.active(isActive: rice.isActive),
                const Spacer(),
                IconButton(
                  tooltip: 'Sửa',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Xóa',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceLabel extends StatelessWidget {
  const _PriceLabel({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
