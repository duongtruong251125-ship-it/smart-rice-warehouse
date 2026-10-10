import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_rice_warehouse/core/routes/app_routes.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/core/utils/number_formatter.dart';
import 'package:smart_rice_warehouse/models/batch_model.dart';
import 'package:smart_rice_warehouse/models/warehouse_location_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';
import 'package:smart_rice_warehouse/widgets/search_field.dart';

class WarehouseLocationScreen extends StatefulWidget {
  const WarehouseLocationScreen({super.key});

  @override
  State<WarehouseLocationScreen> createState() =>
      _WarehouseLocationScreenState();
}

class _WarehouseLocationScreenState extends State<WarehouseLocationScreen> {
  final _searchController = TextEditingController();
  String _selectedZone = 'Tất cả';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddLocationDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final zoneCtrl = TextEditingController(text: 'Khu A');
    final rackCtrl = TextEditingController(text: 'Kệ 3');
    final shelfCtrl = TextEditingController(text: 'Tầng 1');
    final codeCtrl = TextEditingController(text: 'A-K3-T1');
    final capacityCtrl = TextEditingController(text: '2000');
    final descCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Thêm vị trí lưu kho mới'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: zoneCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Khu vực (Zone)'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Nhập khu vực' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: rackCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Kệ (Rack)'),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Nhập kệ' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: shelfCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Tầng (Shelf)'),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Nhập tầng' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(labelText: 'Mã vị trí'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Nhập mã vị trí' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Sức chứa tối đa (kg)'),
                    validator: (v) {
                      final value = double.tryParse(v ?? '');
                      if (value == null || value <= 0) {
                        return 'Sức chứa phải lớn hơn 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Ghi chú mô tả'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final newLoc = WarehouseLocationModel(
                    id: 'loc-${DateTime.now().millisecondsSinceEpoch}',
                    zone: zoneCtrl.text.trim(),
                    rack: rackCtrl.text.trim(),
                    shelf: shelfCtrl.text.trim(),
                    code: codeCtrl.text.trim(),
                    capacity: double.parse(capacityCtrl.text.trim()),
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                  );
                  final added = context.read<WarehouseProvider>().addLocation(
                        newLoc,
                      );
                  if (!added) {
                    AppToast.error(context,
                        'Mã vị trí đã tồn tại hoặc sức chứa không hợp lệ.');
                    return;
                  }
                  Navigator.of(dialogCtx).pop();
                  AppToast.success(
                    context,
                    'Đã thêm vị trí ${newLoc.code}.',
                  );
                }
              },
              child: const Text('Lưu vị trí'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final warehouseProvider = context.watch<WarehouseProvider>();
    final batchProvider = context.watch<BatchProvider>();

    final zones = ['Tất cả', ...warehouseProvider.zones];
    final filteredLocations = warehouseProvider.filter(
      zone: _selectedZone == 'Tất cả' ? null : _selectedZone,
      keyword: _searchQuery,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vị trí kho lưu trữ'),
        actions: [
          IconButton(
            tooltip: 'Thêm vị trí mới',
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () => _showAddLocationDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchField(
              controller: _searchController,
              hintText: 'Tìm theo mã vị trí, kệ, tầng...',
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Lọc theo Khu (Zone Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: zones.map((zone) {
                final isSelected = _selectedZone == zone;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(zone),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedZone = zone),
                    selectedColor: AppTheme.primaryLight,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Danh sách vị trí
          Expanded(
            child: filteredLocations.isEmpty
                ? const EmptyState(
                    message: 'Không tìm thấy vị trí kho nào',
                    icon: Icons.warehouse_outlined,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filteredLocations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final loc = filteredLocations[index];
                      // Tìm các lô đang lưu tại vị trí này
                      final storedBatches = batchProvider.batches
                          .where((b) =>
                              b.warehouseLocationId == loc.id && b.quantity > 0)
                          .toList();
                      final totalWeight = storedBatches.fold<double>(
                        0.0,
                        (sum, b) => sum + b.quantity,
                      );

                      return _LocationCard(
                        location: loc,
                        storedBatches: storedBatches,
                        totalWeight: totalWeight,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatefulWidget {
  const _LocationCard({
    required this.location,
    required this.storedBatches,
    required this.totalWeight,
  });

  final WarehouseLocationModel location;
  final List<BatchModel> storedBatches;
  final double totalWeight;

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;
    final batches = widget.storedBatches;
    final percent = (widget.totalWeight / loc.capacity).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shelves,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            loc.code,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              loc.zone,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${loc.rack} • ${loc.shelf}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${batches.length} lô',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Thanh tiến trình sức chứa
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Tải trọng: ${NumberFormatter.quantity(widget.totalWeight)} / ${NumberFormatter.quantity(loc.capacity)} kg',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(percent * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: percent > 0.85
                            ? AppTheme.dangerColor
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percent > 0.85
                          ? AppTheme.dangerColor
                          : AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),

            if (batches.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _isExpanded
                              ? 'Thu gọn danh sách lô'
                              : 'Xem các lô tại vị trí này (${batches.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppTheme.accentBlue,
                      ),
                    ],
                  ),
                ),
              ),
              if (_isExpanded) ...[
                const Divider(height: 12),
                Column(
                  children: batches.map<Widget>((b) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.qr_code_2_rounded,
                          size: 20, color: AppTheme.textSecondary),
                      title: Text(
                        '${b.code} - ${b.riceName}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Tồn: ${NumberFormatter.quantity(b.quantity)} kg',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 16),
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.batchDetail,
                          arguments: b.id,
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
