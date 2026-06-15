import 'package:intl/intl.dart';

import '../core/constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _formatter = NumberFormat('#,##0.00');

  static String format(double amount) {
    return '${AppConstants.currencySymbol}${_formatter.format(amount)}';
  }

  static String compact(double amount) {
    return '${AppConstants.currency} ${amount.toStringAsFixed(2)}';
  }
}
