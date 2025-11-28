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
import '../../data/repositories/request_repository.dart';
import 'package:flutter/foundation.dart';

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

  Future<void> _loadData() async {
    final user = _authController.currentUser.value;
    if (user == null) return;

    if (user.type.toLowerCase() == 'employee') {
      await _loadMissions(user.id);
    } else {
      await _loadRequests(user.id);
    }
  }

  Future<void> _loadRequests(String userId) async {
    if (!_requestsLoaded || _loadedUserId != userId) {
      try {
        // Charger directement toutes les demandes (y compris completed et cancelled) pour l'historique
        final requestRepository = RequestRepository();
        final allRequests = await requestRepository.getRequestsByClientId(userId);
        // Mettre à jour la liste des demandes dans le controller
        _requestController.requests.assignAll(allRequests);
        _requestsLoaded = true;
        _loadedUserId = userId;
      } catch (e) {
        debugPrint('Error loading requests for history: $e');
      }
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

  Future<void> _loadCancelledRequestsForEmployee(String userId) async {
    try {
      final employee = await _employeeController.getEmployeeByUserId(userId);
      if (employee != null) {
        // Load cancelled requests for this employee
        final cancelledRequests = await _requestController.getCancelledRequestsByEmployeeId(employee.id);
        _requestController.requests.assignAll(cancelledRequests);
        _requestsLoaded = true;
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      appBar: InDriveAppBar(title: 'history'.tr),
      body: SafeArea(
        child: Obx(() {
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

        // For employees, show missions and cancelled requests history
        if (user.type.toLowerCase() == 'employee') {
          // Load cancelled requests for employee
          if (!_requestsLoaded || _loadedUserId != user.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _loadCancelledRequestsForEmployee(user.id);
              }
            });
          }

          if (_missionController.isLoading.value &&
              _missionController.missions.isEmpty &&
              _requestController.isLoading.value &&
              _requestController.requests.isEmpty) {
            return const LoadingWidget();
          }

          // Filter completed or cancelled missions
          final archivedMissions = _missionController.missions
              .where((mission) {
                final status = mission.statutMission.toLowerCase();
                return status == 'completed' || status == 'cancelled';
              })
              .toList();

          // Get cancelled requests for this employee
          final cancelledRequests = _requestController.requests
              .where((req) => req.statut.toLowerCase() == 'cancelled')
              .toList();

          if (archivedMissions.isEmpty && cancelledRequests.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: 'no_history'.tr,
              message: 'no_history_message'.tr,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              if (archivedMissions.isNotEmpty) ...[
                InDriveSectionTitle(
                  title: 'my_missions'.tr,
                  subtitle: 'all_completed_missions'.tr,
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
                                  style: AppTextStyles.h4.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${'mission_date'.tr}: ${_formatDate(mission.dateStart)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              if (cancelledRequests.isNotEmpty) ...[
                if (archivedMissions.isNotEmpty) const SizedBox(height: 32),
                InDriveSectionTitle(
                  title: 'cancelled_requests'.tr,
                  subtitle: 'cancelled_requests_by_clients'.tr,
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cancelledRequests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final request = cancelledRequests[index];
                    return InDriveCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${'request'.tr} #${request.id.substring(0, 8)}',
                                  style: AppTextStyles.h4.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'status_cancelled'.tr,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            request.description,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white70,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${'request_date'.tr}: ${_formatDate(request.createdAt)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        }

        // For clients, show requests history
        if (!_requestsLoaded || _loadedUserId != user.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              await _loadRequests(user.id);
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

        final bottomPadding = MediaQuery.of(context).padding.bottom;
        return ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomPadding),
          children: [
            InDriveSectionTitle(
              title: 'history'.tr,
              subtitle: 'all_completed_requests'.tr,
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
                        style: AppTextStyles.h4.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        request.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 16, color: AppColors.primaryLight),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              request.address,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white70,
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
                          color: Colors.white54,
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
      ),
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

