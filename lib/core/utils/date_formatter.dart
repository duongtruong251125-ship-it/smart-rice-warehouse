import 'package:intl/intl.dart';

abstract final class DateFormatter {
  static final _formatter = DateFormat('dd/MM/yyyy');

  static String ddMMyyyy(DateTime date) {
    return _formatter.format(date);
  }
}
