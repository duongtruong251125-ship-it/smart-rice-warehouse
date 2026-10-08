enum ForecastStatus {
  reorderSoon('Cần nhập gấp'),
  attention('Cần theo dõi'),
  safe('An toàn'),
  noData('Chưa đủ dữ liệu');

  const ForecastStatus(this.label);
  final String label;
}

class ForecastModel {
  const ForecastModel({
    required this.riceId,
    required this.riceName,
    required this.riceCode,
    required this.unit,
    required this.currentStock,
    required this.minimumStock,
    required this.averageDailyExport,
    required this.estimatedDaysRemaining,
    required this.status,
    required this.reorderSuggestion,
  });

  final String riceId;
  final String riceName;
  final String riceCode;
  final String unit;
  final double currentStock;
  final double minimumStock;
  final double averageDailyExport;
  final double? estimatedDaysRemaining;
  final ForecastStatus status;
  final String reorderSuggestion;

  bool get isCritical => status == ForecastStatus.reorderSoon;
}
