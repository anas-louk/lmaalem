/// Modèle de données pour les statistiques d'un employé
class EmployeeStatistics {
  final int totalMissions;
  final int completedMissions;
  final int cancelledMissions;
  final int inProgressMissions;
  final double averageRating;
  final double completionRate; // Pourcentage de missions complétées
  final double totalEarnings; // Revenus totaux
  final int totalRatings; // Nombre de notes reçues

  EmployeeStatistics({
    required this.totalMissions,
    required this.completedMissions,
    required this.cancelledMissions,
    required this.inProgressMissions,
    required this.averageRating,
    required this.completionRate,
    required this.totalEarnings,
    required this.totalRatings,
  });

  /// Créer des statistiques vides (pour nouveaux employés)
  factory EmployeeStatistics.empty() {
    return EmployeeStatistics(
      totalMissions: 0,
      completedMissions: 0,
      cancelledMissions: 0,
      inProgressMissions: 0,
      averageRating: 0.0,
      completionRate: 0.0,
      totalEarnings: 0.0,
      totalRatings: 0,
    );
  }

  /// Vérifier si l'employé a des statistiques
  bool get hasStatistics => totalMissions > 0;

  @override
  String toString() {
    return 'EmployeeStatistics(totalMissions: $totalMissions, completedMissions: $completedMissions, averageRating: $averageRating, completionRate: $completionRate%)';
  }
}

