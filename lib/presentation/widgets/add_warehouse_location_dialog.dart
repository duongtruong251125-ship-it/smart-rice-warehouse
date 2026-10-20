import 'package:flutter/material.dart';
import 'package:smart_rice_warehouse/logic/providers/warehouse_provider.dart';
import 'package:smart_rice_warehouse/logic/services/catalog_form_service.dart';

class AddWarehouseLocationDialog extends StatefulWidget {
  const AddWarehouseLocationDialog({super.key, required this.provider});
  final WarehouseProvider provider;

  @override
  State<AddWarehouseLocationDialog> createState() =>
      _AddWarehouseLocationDialogState();
}

class _AddWarehouseLocationDialogState
    extends State<AddWarehouseLocationDialog> {
  final _form = GlobalKey<FormState>();
  final _zone = TextEditingController(text: 'Khu A');
  final _rack = TextEditingController(text: 'Kệ 3');
  final _shelf = TextEditingController(text: 'Tầng 1');
  final _code = TextEditingController(text: 'A-K3-T1');
  final _capacity = TextEditingController(text: '2000');
  final _description = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _zone,
      _rack,
      _shelf,
      _code,
      _capacity,
      _description
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await CatalogFormService().addLocation(
          provider: widget.provider,
          zone: _zone.text.trim(),
          rack: _rack.text.trim(),
          shelf: _shelf.text.trim(),
          code: _code.text.trim(),
          capacity: double.parse(_capacity.text.trim()),
          description: _description.text);
      if (!mounted) return;
      if (saved) {
        Navigator.of(context).pop(_code.text.trim());
        return;
      }
      setState(() => _error = widget.provider.errorMessage ??
          'Không thể lưu vị trí. Vui lòng thử lại.');
    } catch (error) {
      if (mounted) setState(() => _error = 'Không thể lưu vị trí: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
            controller: controller,
            enabled: !_saving,
            decoration: InputDecoration(labelText: label),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập $label'
                : null),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: const Text('Thêm vị trí lưu kho mới'),
          content: SingleChildScrollView(
              child: Form(
                  key: _form,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _field(_zone, 'Khu vực (Zone)'),
                    _field(_rack, 'Kệ (Rack)'),
                    _field(_shelf, 'Tầng (Shelf)'),
                    _field(_code, 'Mã vị trí'),
                    TextFormField(
                        controller: _capacity,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Sức chứa tối đa (kg)'),
                        validator: (value) {
                          final number = double.tryParse(value?.trim() ?? '');
                          return number == null ||
                                  !number.isFinite ||
                                  number <= 0
                              ? 'Sức chứa phải là số hữu hạn lớn hơn 0'
                              : null;
                        }),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: _description,
                        enabled: !_saving,
                        decoration:
                            const InputDecoration(labelText: 'Ghi chú mô tả')),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              key: const Key('location-save-error'))),
                  ]))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Hủy')),
            ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Đang lưu...' : 'Lưu vị trí')),
          ],
        ),
      );
}
