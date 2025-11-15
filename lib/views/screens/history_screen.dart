import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';

/// Écran d'historique des missions
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final MissionController _missionController = Get.put(MissionController());
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  void _loadMissions() {
    final user = _authController.currentUser.value;
    if (user != null && !_hasLoaded) {
      if (user.type.toLowerCase() == 'employee') {
        _missionController.loadMissionsByEmployee(user.id);
      } else {
        _missionController.loadMissionsByClient(user.id);
      }
      _hasLoaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
      ),
      body: Obx(
        () {
          final user = _authController.currentUser.value;

          if (user == null) {
            return const LoadingWidget();
          }

          // Recharger si l'utilisateur change
          if (!_hasLoaded) {
            _loadMissions();
          }

          if (_missionController.isLoading.value) {
            return const LoadingWidget();
          }

          if (_missionController.missions.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: 'Aucun historique',
              message: 'Vous n\'avez pas encore de missions',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _missionController.missions.length,
            itemBuilder: (context, index) {
              final mission = _missionController.missions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(mission.statutMission),
                    child: Icon(
                      _getStatusIcon(mission.statutMission),
                      color: AppColors.white,
                    ),
                  ),
                  title: Text(
                    'Mission #${mission.id.substring(0, 8)}',
                    style: AppTextStyles.h4,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Objectif: ${mission.objMission}',
                        style: AppTextStyles.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Prix: ${mission.prixMission.toStringAsFixed(2)} €',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${_formatDate(mission.dateStart)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(mission.statutMission),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      mission.statutMission,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  onTap: () {
                    _missionController.selectMission(mission);
                    Get.toNamed(AppRoutes.AppRoutes.missionDetail);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'in progress':
        return AppColors.info;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  IconData _getStatusIcon(String statut) {
    switch (statut.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'in progress':
        return Icons.work;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

