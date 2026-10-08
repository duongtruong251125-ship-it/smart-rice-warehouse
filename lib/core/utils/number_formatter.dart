abstract final class NumberFormatter {
  static String quantity(double value) {
    if (value == value.roundToDouble()) {
      return _withThousandsSeparator(value.toInt());
    }
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String _withThousandsSeparator(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[index]);
    }

    return buffer.toString();
  }
}
