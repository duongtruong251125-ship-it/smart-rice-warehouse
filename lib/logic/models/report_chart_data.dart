/// Chart input data without dependencies on Flutter, colors or chart widgets.
class ReportFlowPoint {
  const ReportFlowPoint({
    required this.label,
    required this.importQuantity,
    required this.exportQuantity,
  });
  final String label;
  final double importQuantity;
  final double exportQuantity;
}

class ReportValuePoint {
  const ReportValuePoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

class InventoryQuantity {
  const InventoryQuantity({required this.label, required this.quantity});
  final String label;
  final double quantity;
}
