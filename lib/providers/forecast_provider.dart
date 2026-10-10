import 'package:flutter/foundation.dart';
import 'package:smart_rice_warehouse/models/export_receipt_model.dart';
import 'package:smart_rice_warehouse/models/forecast_model.dart';
import 'package:smart_rice_warehouse/models/rice_model.dart';
import 'package:smart_rice_warehouse/providers/batch_provider.dart';
import 'package:smart_rice_warehouse/services/forecast_service.dart';

class ForecastProvider extends ChangeNotifier {
  ForecastProvider();

  final ForecastService _service = const ForecastService();
  List<ForecastModel> _forecasts = <ForecastModel>[];

  List<ForecastModel> get forecasts =>
      List<ForecastModel>.unmodifiable(_forecasts);

  int get reorderSoonCount =>
      _forecasts.where((f) => f.status == ForecastStatus.reorderSoon).length;

  int get attentionCount =>
      _forecasts.where((f) => f.status == ForecastStatus.attention).length;

  List<ForecastModel> get criticalForecasts => _forecasts
      .where((f) => f.status == ForecastStatus.reorderSoon)
      .toList(growable: false);

  void refreshForecasts({
    required List<RiceModel> rices,
    required List<ExportReceiptModel> exportReceipts,
    required BatchProvider batchProvider,
    DateTime? referenceDate,
  }) {
    _forecasts = _service.generateForecasts(
      rices: rices,
      exportReceipts: exportReceipts,
      batchProvider: batchProvider,
      referenceDate: referenceDate,
    );
    notifyListeners();
  }
}
