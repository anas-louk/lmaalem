import 'package:intl/intl.dart';

/// Helper pour formater les dates
class DateFormatter {
  DateFormatter._(); // Private constructor

  /// Formate une date en format court (ex: 15 Jan 2024)
  static String formatShort(DateTime date) {
    return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
  }

  /// Formate une date en format long (ex: 15 janvier 2024)
  static String formatLong(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'fr_FR').format(date);
  }

  /// Formate une date avec l'heure (ex: 15 Jan 2024, 14:30)
  static String formatWithTime(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(date);
  }

  /// Formate une date relative (ex: Il y a 2 heures)
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return 'Il y a $years ${years > 1 ? 'ans' : 'an'}';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a $months ${months > 1 ? 'mois' : 'mois'}';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} ${difference.inDays > 1 ? 'jours' : 'jour'}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} ${difference.inHours > 1 ? 'heures' : 'heure'}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} ${difference.inMinutes > 1 ? 'minutes' : 'minute'}';
    } else {
      return 'À l\'instant';
    }
  }
}

