import 'package:flutter_test/flutter_test.dart';
import 'package:smart_rice_warehouse/models/rice_characteristic_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/rice_characteristic_provider.dart';
import 'package:smart_rice_warehouse/providers/rice_provider.dart';

void main() {
  group('RiceCharacteristicModel Tests', () {
    test('Khởi tạo và serialization toJson / fromJson', () {
      const model = RiceCharacteristicModel(
        id: 'char-1',
        name: 'Dẻo nhiều',
        description: 'Hạt cơm dẻo quánh',
        colorValue: 0xFF2E7D32,
        isDefault: false,
      );

      final json = model.toJson();
      expect(json['id'], 'char-1');
      expect(json['name'], 'Dẻo nhiều');
      expect(json['description'], 'Hạt cơm dẻo quánh');
      expect(json['colorValue'], 0xFF2E7D32);
      expect(json['isDefault'], false);

      final restored = RiceCharacteristicModel.fromJson(json);
      expect(restored.id, model.id);
      expect(restored.name, model.name);
      expect(restored.description, model.description);
      expect(restored.colorValue, model.colorValue);
      expect(restored.isDefault, model.isDefault);
    });

    test('copyWith hoạt động chính xác', () {
      const model = RiceCharacteristicModel(
        id: 'char-1',
        name: 'Dẻo',
        colorValue: 0xFF2E7D32,
      );

      final updated = model.copyWith(
        name: 'Cực dẻo',
        description: 'Mới cập nhật',
      );

      expect(updated.id, 'char-1');
      expect(updated.name, 'Cực dẻo');
      expect(updated.description, 'Mới cập nhật');
      expect(updated.colorValue, 0xFF2E7D32);
    });
  });

  group('RiceModel characteristicIds backward compatibility', () {
    test('JSON không có characteristicIds vẫn parse ra danh sách rỗng', () {
      final json = {
        'id': 'rice-1',
        'code': 'GAO-001',
        'name': 'Gạo Test',
        'category': 'Gạo thơm',
        'unit': 'kg',
        'purchasePrice': 15000.0,
        'sellingPrice': 20000.0,
        'minimumStock': 100.0,
        'description': '',
        'isActive': true,
      };

      final rice = RiceModel.fromJson(json);
      expect(rice.characteristicIds, isEmpty);
    });

    test('JSON có characteristicIds được parse chính xác', () {
      final json = {
        'id': 'rice-1',
        'code': 'GAO-001',
        'name': 'Gạo ST25',
        'category': 'Gạo thơm',
        'unit': 'kg',
        'purchasePrice': 25000.0,
        'sellingPrice': 32000.0,
        'minimumStock': 200.0,
        'description': 'Đặc sản Sóc Trăng',
        'isActive': true,
        'characteristicIds': ['char_deo', 'char_thom'],
      };

      final rice = RiceModel.fromJson(json);
      expect(rice.characteristicIds, ['char_deo', 'char_thom']);
      expect(rice.toJson()['characteristicIds'], ['char_deo', 'char_thom']);
    });
  });

  group('RiceCharacteristicProvider Tests', () {
    test('CRUD đặc tính gạo hoạt động trơn tru', () {
      final provider = RiceCharacteristicProvider(
        initial: [
          const RiceCharacteristicModel(
            id: 'char_deo',
            name: 'Dẻo',
            colorValue: 0xFF2E7D32,
            isDefault: true,
          ),
          const RiceCharacteristicModel(
            id: 'char_thom',
            name: 'Thơm',
            colorValue: 0xFFE65100,
            isDefault: true,
          ),
        ],
      );

      expect(provider.characteristics.length, 2);

      // 1. Thêm mới
      const newChar = RiceCharacteristicModel(
        id: 'char_custom_1',
        name: 'Xốp mềm',
        description: 'Cơm nở xốp, tơi hạt',
        colorValue: 0xFF0288D1,
      );
      final added = provider.addCharacteristic(newChar);
      expect(added, isTrue);
      expect(provider.characteristics.length, 3);
      expect(provider.findById('char_custom_1')?.name, 'Xốp mềm');
      expect(provider.findById('char_custom_1')?.description, 'Cơm nở xốp, tơi hạt');

      // 2. Trùng tên (case-insensitive)
      expect(provider.isNameExists('xốp mềm'), isTrue);
      expect(provider.isNameExists('XỐP MỀM'), isTrue);
      expect(provider.isNameExists('Giòn rụm'), isFalse);

      // 3. Cập nhật
      final updated = provider.updateCharacteristic(
        newChar.copyWith(name: 'Xốp nở'),
      );
      expect(updated, isTrue);
      expect(provider.findById('char_custom_1')?.name, 'Xốp nở');

      // 4. Lấy theo danh sách ID
      final retrieved = provider.getCharacteristicsForIds(['char_deo', 'char_custom_1']);
      expect(retrieved.length, 2);
      expect(retrieved.map((c) => c.name), containsAll(['Dẻo', 'Xốp nở']));

      // 5. Xóa
      final deleted = provider.deleteCharacteristic('char_custom_1');
      expect(deleted, isTrue);
      expect(provider.characteristics.length, 2);
      expect(provider.findById('char_custom_1'), isNull);
    });
  });

  group('RiceProvider Filtering & Cascade Cleanup with Characteristics', () {
    test('Lọc gạo đa điều kiện theo từ khóa và đặc tính', () {
      const rice1 = RiceModel(
        id: 'r1',
        code: 'ST25',
        name: 'Gạo ST25 Ông Cua',
        category: 'Gạo cao cấp',
        unit: 'kg',
        purchasePrice: 28000,
        sellingPrice: 35000,
        minimumStock: 100,
        description: '',
        isActive: true,
        characteristicIds: ['c_deo', 'c_thom'],
      );

      const rice2 = RiceModel(
        id: 'r2',
        code: 'JAS',
        name: 'Gạo Jasmine Thơm',
        category: 'Gạo thơm',
        unit: 'kg',
        purchasePrice: 18000,
        sellingPrice: 22000,
        minimumStock: 100,
        description: '',
        isActive: true,
        characteristicIds: ['c_thom', 'c_mem'],
      );

      const rice3 = RiceModel(
        id: 'r3',
        code: '504',
        name: 'Gạo IR50404 Xốp',
        category: 'Gạo phổ thông',
        unit: 'kg',
        purchasePrice: 14000,
        sellingPrice: 17000,
        minimumStock: 100,
        description: '',
        isActive: true,
        characteristicIds: ['c_xop', 'c_kho'],
      );

      final riceProvider = RiceProvider(initial: [rice1, rice2, rice3]);

      // Lọc không truyền gì -> trả về tất cả
      expect(riceProvider.filterRices().length, 3);

      // Lọc theo đặc tính c_thom -> r1 và r2
      final thomResults = riceProvider.filterRices(
        selectedCharacteristicIds: {'c_thom'},
      );
      expect(thomResults.map((r) => r.id), containsAll(['r1', 'r2']));
      expect(thomResults.length, 2);

      // Lọc theo cả c_deo và c_thom -> chỉ r1 thỏa mãn cả hai
      final deoAndThomResults = riceProvider.filterRices(
        selectedCharacteristicIds: {'c_deo', 'c_thom'},
      );
      expect(deoAndThomResults.length, 1);
      expect(deoAndThomResults.first.id, 'r1');

      // Lọc kết hợp search query và đặc tính
      final combinedResults = riceProvider.filterRices(
        query: 'Jasmine',
        selectedCharacteristicIds: {'c_mem'},
      );
      expect(combinedResults.length, 1);
      expect(combinedResults.first.id, 'r2');

      // Đếm số lượng gạo có đặc tính
      expect(riceProvider.countRicesWithCharacteristic('c_thom'), 2);
      expect(riceProvider.countRicesWithCharacteristic('c_deo'), 1);
      expect(riceProvider.countRicesWithCharacteristic('c_xop'), 1);
      expect(riceProvider.countRicesWithCharacteristic('non_existent'), 0);
    });

    test('Xóa đặc tính tự động gỡ bỏ khỏi toàn bộ gạo liên quan', () {
      const rice1 = RiceModel(
        id: 'r1',
        code: 'R1',
        name: 'Gạo 1',
        category: 'Loại 1',
        unit: 'kg',
        purchasePrice: 10000,
        sellingPrice: 12000,
        minimumStock: 50,
        description: '',
        isActive: true,
        characteristicIds: ['c_target', 'c_other'],
      );

      const rice2 = RiceModel(
        id: 'r2',
        code: 'R2',
        name: 'Gạo 2',
        category: 'Loại 2',
        unit: 'kg',
        purchasePrice: 10000,
        sellingPrice: 12000,
        minimumStock: 50,
        description: '',
        isActive: true,
        characteristicIds: ['c_target'],
      );

      final riceProvider = RiceProvider(initial: [rice1, rice2]);

      expect(riceProvider.countRicesWithCharacteristic('c_target'), 2);

      // Cascade remove
      riceProvider.removeCharacteristicFromAll('c_target');

      expect(riceProvider.countRicesWithCharacteristic('c_target'), 0);
      expect(riceProvider.findById('r1')?.characteristicIds, ['c_other']);
      expect(riceProvider.findById('r2')?.characteristicIds, isEmpty);
    });
  });
}
