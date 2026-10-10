import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'VNĐ',
    decimalDigits: 0,
  );

  static String formatVnd(double amount) {
    return _formatter.format(amount);
  }
}
