import 'package:flutter/material.dart';
import '../data/models/employee_statistics.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import 'package:get/get.dart';

/// Widget pour afficher les statistiques d'un employé
/// Peut être utilisé en mode compact (brief) ou complet (full)
class EmployeeStatisticsWidget extends StatelessWidget {
  final EmployeeStatistics statistics;
  final bool isCompact; // Si true, affiche une version compacte pour les cartes

  const EmployeeStatisticsWidget({
    super.key,
    required this.statistics,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!statistics.hasStatistics) {
      return _buildNoStatistics();
    }

    if (isCompact) {
      return _buildCompactView();
    }

    return _buildFullView();
  }

  /// Vue compacte pour les cartes d'acceptation
  Widget _buildCompactView() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primaryLight.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.check_circle,
            label: 'completed'.tr,
            value: '${statistics.completedMissions}',
            color: AppColors.success,
          ),
          _buildStatItem(
            icon: Icons.star,
            label: 'rating'.tr,
            value: statistics.averageRating > 0
                ? statistics.averageRating.toStringAsFixed(1)
                : 'N/A',
            color: AppColors.warning,
          ),
          _buildStatItem(
            icon: Icons.percent,
            label: 'completion_rate'.tr,
            value: '${statistics.completionRate.toStringAsFixed(0)}%',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  /// Vue complète pour le profil
  Widget _buildFullView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'statistics'.tr,
          style: AppTextStyles.h3,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.work_outline,
                label: 'total_missions'.tr,
                value: '${statistics.totalMissions}',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_outline,
                label: 'completed_missions'.tr,
                value: '${statistics.completedMissions}',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.star_outline,
                label: 'average_rating'.tr,
                value: statistics.averageRating > 0
                    ? statistics.averageRating.toStringAsFixed(1)
                    : 'N/A',
                color: AppColors.warning,
                subtitle: statistics.totalRatings > 0
                    ? '${statistics.totalRatings} ${'ratings'.tr}'
                    : 'no_ratings'.tr,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.percent,
                label: 'completion_rate'.tr,
                value: '${statistics.completionRate.toStringAsFixed(1)}%',
                color: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.attach_money,
                label: 'total_earnings'.tr,
                value: '${statistics.totalEarnings.toStringAsFixed(0)} ${'currency'.tr}',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.cancel_outlined,
                label: 'cancelled_missions'.tr,
                value: '${statistics.cancelledMissions}',
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Widget pour un élément de statistique compact
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Widget pour une carte de statistique complète
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.h3.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Widget pour afficher quand il n'y a pas de statistiques
  Widget _buildNoStatistics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primaryLight.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'no_statistics_available'.tr,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

