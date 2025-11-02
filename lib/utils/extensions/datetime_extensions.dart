import '../../core/helpers/date_formatter.dart';

/// Extensions pour DateTime
extension DateTimeExtensions on DateTime {
  /// Formater en format court
  String toShortString() => DateFormatter.formatShort(this);

  /// Formater en format long
  String toLongString() => DateFormatter.formatLong(this);

  /// Formater avec l'heure
  String toDateTimeString() => DateFormatter.formatWithTime(this);

  /// Formater en relatif
  String toRelativeString() => DateFormatter.formatRelative(this);

  /// Vérifier si la date est aujourd'hui
  bool isToday() {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Vérifier si la date est cette semaine
  bool isThisWeek() {
    final now = DateTime.now();
    final difference = now.difference(this).inDays;
    return difference >= 0 && difference < 7;
  }
}

