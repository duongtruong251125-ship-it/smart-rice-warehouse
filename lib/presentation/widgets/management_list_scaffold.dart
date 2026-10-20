import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/presentation/theme/app_theme.dart';
import 'package:smart_rice_warehouse/presentation/widgets/async_status_banner.dart';
import 'package:smart_rice_warehouse/presentation/widgets/empty_state.dart';
import 'package:smart_rice_warehouse/presentation/widgets/search_field.dart';

class ManagementListScaffold extends StatelessWidget {
  const ManagementListScaffold({
    super.key,
    required this.title,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    this.onAdd,
    required this.addLabel,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.hasSearchQuery,
    this.roleBanner,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  final String title;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onAdd;
  final String addLabel;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool hasSearchQuery;
  final Widget? roleBanner;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (roleBanner != null) roleBanner!,
          AsyncStatusBanner(
            isLoading: isLoading,
            errorMessage: errorMessage,
            onRetry: onRetry,
          ),
          Container(
            color: AppTheme.cardBg(context),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchField(
                  controller: searchController,
                  hintText: searchHint,
                  onChanged: onSearchChanged,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.list_alt_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tổng cộng: $itemCount mục',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppTheme.textSecondaryColor(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
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
            child: itemCount == 0
                ? EmptyState(
                    icon: emptyIcon,
                    message: hasSearchQuery
                        ? 'Không tìm thấy kết quả phù hợp'
                        : emptyMessage,
                    actionLabel:
                        (hasSearchQuery || onAdd == null) ? null : addLabel,
                    onAction: (hasSearchQuery || onAdd == null) ? null : onAdd,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: itemCount,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: itemBuilder,
                  ),
          ),
        ],
      ),
      floatingActionButton: onAdd == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(addLabel),
            ),
    );
  }
}

class StaffReadOnlyBanner extends StatelessWidget {
  const StaffReadOnlyBanner({
    super.key,
    this.message =
        'Quyền Nhân viên kho: Chỉ xem danh mục gốc (Liên hệ Quản trị viên để chỉnh sửa)',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.accentBlue.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.visibility_outlined,
            size: 16,
            color: AppTheme.accentBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF93C5FD) : AppTheme.accentBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
