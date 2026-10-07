abstract final class CurrencyFormatter {
  static String formatVnd(double amount) {
    final roundedAmount = amount.round();
    final digits = roundedAmount.toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[index]);
    }

    return '${buffer.toString()} ₫';
  }
}
