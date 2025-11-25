import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/request_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import '../../components/indrive_app_bar.dart';
import '../../components/indrive_card.dart';
import '../../components/indrive_section_title.dart';

/// Historique des demandes annulées
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final RequestController _requestController = Get.put(RequestController());
  final MissionController _missionController = Get.put(MissionController());
  final EmployeeController _employeeController = Get.put(EmployeeController());
  bool _requestsLoaded = false;
  bool _missionsLoaded = false;
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final user = _authController.currentUser.value;
    if (user == null) return;

    if (user.type.toLowerCase() == 'employee') {
      _loadMissions(user.id);
    } else {
      _loadRequests(user.id);
    }
  }

  void _loadRequests(String userId) {
    if (!_requestsLoaded || _loadedUserId != userId) {
      _requestController.streamRequestsByClient(userId);
      _requestsLoaded = true;
      _loadedUserId = userId;
    }
  }

  Future<void> _loadMissions(String userId) async {
    if (!_missionsLoaded || _loadedUserId != userId) {
      try {
        final employee = await _employeeController.getEmployeeByUserId(userId);
        if (employee != null) {
          await _missionController.streamMissionsByEmployee(employee.id);
          _missionsLoaded = true;
          _loadedUserId = userId;
        }
      } catch (e) {
        // Handle error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InDriveAppBar(title: 'history'.tr),
      body: Obx(() {
        final user = _authController.currentUser.value;
        if (user == null) {
          return const LoadingWidget();
        }

        // Reload if user changes
        if (_loadedUserId != user.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadData();
            }
          });
        }

        // For employees, show missions history
        if (user.type.toLowerCase() == 'employee') {
          if (_missionController.isLoading.value &&
              _missionController.missions.isEmpty) {
            return const LoadingWidget();
          }

          // Filter completed or cancelled missions
          final archivedMissions = _missionController.missions
              .where((mission) {
                final status = mission.statutMission.toLowerCase();
                return status == 'completed' || status == 'cancelled';
              })
              .toList();

          if (archivedMissions.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: 'no_history'.tr,
              message: 'no_history_message'.tr,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              InDriveSectionTitle(
                title: 'my_missions'.tr,
                subtitle: 'Toutes les missions terminées ou annulées.',
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: archivedMissions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final mission = archivedMissions[index];
                  final statusColor = _getMissionStatusColor(mission.statutMission);
                  return InDriveCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${'mission'.tr} #${mission.id.substring(0, 8)}',
                                style: AppTextStyles.h4,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _getMissionStatusText(mission.statutMission),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${'mission_price'.tr}: ${mission.prixMission.toStringAsFixed(2)} DH',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${'mission_date'.tr}: ${_formatDate(mission.dateStart)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        }

        // For clients, show requests history
        if (!_requestsLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadRequests(user.id);
            }
          });
        }

        if (_requestController.isLoading.value &&
            _requestController.requests.isEmpty) {
          return const LoadingWidget();
        }

        final archivedRequests = _requestController.requests
            .where((req) {
              final status = req.statut.toLowerCase();
              return status == 'cancelled' || status == 'completed';
            })
            .toList();

        if (archivedRequests.isEmpty) {
          return EmptyState(
            icon: Icons.history,
            title: 'no_history'.tr,
            message: 'no_history_message'.tr,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            InDriveSectionTitle(
              title: 'history'.tr,
              subtitle: 'Toutes les demandes terminées ou annulées.',
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: archivedRequests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final request = archivedRequests[index];
                final statusColor = _getStatusColor(request.statut);
                return InDriveCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${request.id.substring(0, 8)}',
                        style: AppTextStyles.h4,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        request.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              request.address,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${'mission_date'.tr}: ${_formatDate(request.createdAt)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _getStatusText(request.statut),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      }),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  String _getStatusText(String statut) {
    switch (statut.toLowerCase()) {
      case 'completed':
        return 'status_completed'.tr;
      case 'cancelled':
        return 'status_cancelled'.tr;
      default:
        return statut;
    }
  }

  Color _getMissionStatusColor(String statut) {
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

  String _getMissionStatusText(String statut) {
    switch (statut.toLowerCase()) {
      case 'pending':
        return 'status_pending'.tr;
      case 'in progress':
        return 'status_in_progress'.tr;
      case 'completed':
        return 'status_completed'.tr;
      case 'cancelled':
        return 'status_cancelled'.tr;
      default:
        return statut;
    }
  }
}

