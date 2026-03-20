import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );
  static final DateFormat _date = DateFormat('dd MMM');
  static final DateFormat _dateLong = DateFormat('dd MMM yyyy');
  static final DateFormat _time = DateFormat('hh:mm a');
  static final DateFormat _dayTime = DateFormat('EEE, hh:mm a');

  static String currency(num value) => _currency.format(value);
  static String date(DateTime value) => _date.format(value);
  static String dateLong(DateTime value) => _dateLong.format(value);
  static String time(DateTime value) => _time.format(value);
  static String dayTime(DateTime value) => _dayTime.format(value);
  static String distance(double km) => '${km.toStringAsFixed(1)} km';
  static String minutes(int value) => '$value min';
}
