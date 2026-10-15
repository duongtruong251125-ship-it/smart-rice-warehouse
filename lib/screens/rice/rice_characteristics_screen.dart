import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_rice_warehouse/core/theme/app_theme.dart';
import 'package:smart_rice_warehouse/core/utils/app_toast.dart';
import 'package:smart_rice_warehouse/models/rice_characteristic_model.dart';
import 'package:smart_rice_warehouse/providers/rice_characteristic_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';
import 'package:smart_rice_warehouse/widgets/confirmation_dialog.dart';
import 'package:smart_rice_warehouse/widgets/empty_state.dart';

const List<int> kCharacteristicColors = <int>[
  0xFF0D9488, // Teal
  0xFFD97706, // Amber
  0xFF2563EB, // Blue
  0xFF7C3AED, // Purple
  0xFFB45309, // Brown
  0xFFE11D48, // Rose
  0xFF059669, // Emerald
  0xFF4F46E5, // Indigo
  0xFFEA580C, // Orange
  0xFF0891B2, // Cyan
];

class RiceCharacteristicsScreen extends StatelessWidget {
  const RiceCharacteristicsScreen({super.key});

  static Future<void> showAddOrEditDialog(
    BuildContext context, {
    RiceCharacteristicModel? characteristic,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController =
        TextEditingController(text: characteristic?.name ?? '');
    final descController =
        TextEditingController(text: characteristic?.description ?? '');
    int selectedColor = characteristic?.colorValue ?? kCharacteristicColors.first;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final isEditing = characteristic != null;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(selectedColor).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(selectedColor),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing ? 'Sửa đặc tính gạo' : 'Thêm đặc tính mới',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên đặc tính
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Tên đặc tính *',
                          hintText: 'Ví dụ: Dẻo, Xốp, Thơm, Khô...',
                          prefixIcon: Icon(Icons.label_outline_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập tên đặc tính';
                          }
                          final exists = context
                              .read<RiceCharacteristicProvider>()
                              .isNameExists(
                                value.trim(),
                                excludeId: characteristic?.id,
                              );
                          if (exists) {
                            return 'Tên đặc tính này đã tồn tại';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Mô tả
                      TextFormField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả chi tiết (không bắt buộc)',
                          hintText: 'Ví dụ: Hạt cơm mềm tơi, để nguội không bị cứng...',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Chọn màu sắc nhận diện
                      Text(
                        'Màu sắc nhận diện (Tag Color):',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kCharacteristicColors.map((colorVal) {
                          final isSelected = selectedColor == colorVal;
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = colorVal;
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Color(colorVal),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.onSurface
                                      : Colors.transparent,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: Color(colorVal).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
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
                FilledButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    final provider =
                        context.read<RiceCharacteristicProvider>();
                    if (isEditing) {
                      final updated = characteristic.copyWith(
                        name: nameController.text.trim(),
                        description: descController.text.trim(),
                        colorValue: selectedColor,
                      );
                      provider.updateCharacteristic(updated);
                      AppToast.success(
                          context, 'Đã cập nhật đặc tính "${updated.name}"');
                    } else {
                      final newChar = RiceCharacteristicModel(
                        id: 'char-${const Uuid().v4().substring(0, 8)}',
                        name: nameController.text.trim(),
                        description: descController.text.trim(),
                        colorValue: selectedColor,
                        isDefault: false,
                      );
                      provider.addCharacteristic(newChar);
                      AppToast.success(
                          context, 'Đã thêm đặc tính "${newChar.name}"');
                    }
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCharacteristic(
    BuildContext context,
    RiceCharacteristicModel characteristic,
  ) async {
    final riceProvider = context.read<RiceProvider>();
    final count =
        riceProvider.countRicesWithCharacteristic(characteristic.id);

    final String message;
    if (count > 0) {
      message =
          'Đặc tính "${characteristic.name}" đang được áp dụng cho $count loại gạo.\n\nKhi xóa, đặc tính này sẽ tự động gỡ bỏ khỏi các loại gạo đó (không làm mất gạo). Bạn có chắc chắn muốn xóa không?';
    } else {
      message =
          'Bạn có chắc chắn muốn xóa đặc tính "${characteristic.name}" không?';
    }

    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Xóa đặc tính gạo',
      message: message,
      confirmLabel: 'Xác nhận xóa',
    );

    if (confirmed && context.mounted) {
      final charProvider = context.read<RiceCharacteristicProvider>();
      charProvider.deleteCharacteristic(
        characteristic.id,
        onDeleted: (deletedId) {
          riceProvider.removeCharacteristicFromAll(deletedId);
        },
      );
      if (context.mounted) {
        AppToast.success(context, 'Đã xóa đặc tính "${characteristic.name}"');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final charProvider = context.watch<RiceCharacteristicProvider>();
    final riceProvider = context.watch<RiceProvider>();
    final characteristics = charProvider.characteristics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý đặc tính gạo'),
        actions: [
          IconButton(
            tooltip: 'Thêm đặc tính',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => showAddOrEditDialog(context),
          ),
        ],
      ),
      body: characteristics.isEmpty
          ? EmptyState(
              icon: Icons.auto_awesome_outlined,
              message: 'Chưa có đặc tính gạo nào',
              actionLabel: 'Thêm đặc tính đầu tiên',
              onAction: () => showAddOrEditDialog(context),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                // Banner giới thiệu tính năng
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: colorScheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tự do định nghĩa các đặc tính cảm quan & nấu nướng (Dẻo, Xốp, Thơm,...). Gán đặc tính cho từng loại gạo để tìm kiếm và tư vấn nhanh.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Danh sách các thẻ đặc tính
                ...characteristics.map((char) {
                  final color = Color(char.colorValue);
                  final riceCount =
                      riceProvider.countRicesWithCharacteristic(char.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tag màu
                          Container(
                            width: 12,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Nội dung
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        char.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$riceCount loại gạo',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (char.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    char.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Actions
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Chỉnh sửa',
                                onPressed: () => showAddOrEditDialog(
                                  context,
                                  characteristic: char,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: AppTheme.dangerColor),
                                tooltip: 'Xóa đặc tính',
                                onPressed: () =>
                                    _deleteCharacteristic(context, char),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddOrEditDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm đặc tính'),
      ),
    );
  }
}
