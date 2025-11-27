import 'dart:math';

/// Utilitaire pour calculer les distances entre deux points GPS
class DistanceCalculator {
  /// Rayon de la Terre en kilomètres
  static const double earthRadiusKm = 6371.0;

  /// Calculer la distance entre deux points GPS en kilomètres (formule de Haversine)
  /// 
  /// [lat1] Latitude du premier point
  /// [lon1] Longitude du premier point
  /// [lat2] Latitude du second point
  /// [lon2] Longitude du second point
  /// 
  /// Retourne la distance en kilomètres
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadiusKm * c;

    return distance;
  }

  /// Convertir les degrés en radians
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Formater la distance pour l'affichage
  /// 
  /// [distanceKm] Distance en kilomètres
  /// 
  /// Retourne une chaîne formatée (ex: "2.5 km" ou "500 m")
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }
}

