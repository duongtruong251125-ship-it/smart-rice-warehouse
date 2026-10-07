import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';
import 'package:smart_rice_warehouse/widgets/search_field.dart';

class ManagementListScaffold extends StatelessWidget {
  const ManagementListScaffold({
    super.key,
    required this.title,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    required this.onAdd,
    required this.addLabel,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.hasSearchQuery,
  });

  final String title;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAdd;
  final String addLabel;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool hasSearchQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Container(
            color: Colors.white,
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
                    Icon(
                      Icons.list_alt_rounded,
                      size: 15,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tổng cộng: $itemCount mục',
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
            child: itemCount == 0
                ? EmptyState(
                    icon: emptyIcon,
                    message: hasSearchQuery
                        ? 'Không tìm thấy kết quả phù hợp'
                        : emptyMessage,
                    actionLabel: hasSearchQuery ? null : addLabel,
                    onAction: hasSearchQuery ? null : onAdd,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: Text(addLabel),
      ),
    );
  }
}

