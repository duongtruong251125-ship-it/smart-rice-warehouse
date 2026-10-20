import 'dart:async';
import 'package:smart_rice_warehouse/data/local/image_storage_service.dart';
import 'package:smart_rice_warehouse/data/mock/mock_data.dart';
import 'package:smart_rice_warehouse/logic/contracts/initial_data_provider.dart';
import 'package:smart_rice_warehouse/logic/services/media_service.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  DefaultDataRegistry.provider = const MockInitialDataProvider();
  MediaService.initialize(const LocalMediaStorage());
  await testMain();
}
