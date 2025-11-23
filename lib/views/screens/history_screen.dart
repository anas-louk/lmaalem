import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/request_controller.dart';
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
  bool _requestsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRequests());
  }

  void _loadRequests() {
    final user = _authController.currentUser.value;
    if (user != null && !_requestsLoaded) {
      _requestController.streamRequestsByClient(user.id);
      _requestsLoaded = true;
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

        if (!_requestsLoaded) {
          _loadRequests();
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
}

