import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../controllers/request_controller.dart';
import '../../data/models/request_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import '../../components/indrive_bottom_nav.dart';
import '../../components/indrive_app_bar.dart';
import '../../components/indrive_card.dart';
import '../../components/indrive_button.dart';
import '../../components/indrive_section_title.dart';
import '../../components/indrive_dialog_template.dart';
import 'history_screen.dart';
import 'categories_screen.dart';

/// Dashboard Client with Bottom Navigation
class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  int _currentIndex = 1; // Default to Home (middle)

  final List<Widget> _screens = [
    const HistoryScreen(),
    const _ClientHomeScreen(),
    const CategoriesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: InDriveBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_outlined),
            activeIcon: const Icon(Icons.history),
            label: 'history'.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: 'home'.tr,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.category_outlined),
            activeIcon: const Icon(Icons.category),
            label: 'categories'.tr,
          ),
        ],
      ),
    );
  }
}

/// Home screen content for Client
class _ClientHomeScreen extends StatefulWidget {
  const _ClientHomeScreen();

  @override
  State<_ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<_ClientHomeScreen> with WidgetsBindingObserver {
  final AuthController _authController = Get.find<AuthController>();
  final MissionController _missionController = Get.put(MissionController());
  final RequestController _requestController = Get.put(RequestController());
  final ClientRepository _clientRepository = ClientRepository();
  String? _loadedUserId;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _lastRefreshTime = DateTime.now();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh when app comes back to foreground
      _refreshData();
    }
  }

  void _loadData({bool forceRefresh = false}) {
    final user = _authController.currentUser.value;
    if (user != null) {
      // Always reload if forceRefresh is true, otherwise only if user changed
      if (forceRefresh || _loadedUserId != user.id) {
        // Get client document ID for missions
        _loadClientAndRefresh(user.id);
        // Stream requests for real-time updates and global notifications
        _requestController.streamRequestsByClient(user.id);
        _loadedUserId = user.id;
        _lastRefreshTime = DateTime.now();
      }
    }
  }

  void _refreshData() {
    // Only refresh if enough time has passed since last refresh (debounce)
    if (_lastRefreshTime == null || 
        DateTime.now().difference(_lastRefreshTime!).inSeconds > 1) {
      _loadData(forceRefresh: true);
    }
  }

  Future<void> _loadClientAndRefresh(String userId) async {
    try {
      // Get client document ID from user ID
      final client = await _clientRepository.getClientByUserId(userId);
      if (client != null) {
        // Stream missions for real-time updates
        await _missionController.streamMissionsByClient(client.id);
      } else {
        // If client not found, clear missions
        _missionController.missions.clear();
      }
    } catch (e) {
      // If error, missions will be empty
      _missionController.missions.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InDriveAppBar(
        title: 'client_dashboard'.tr,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Get.toNamed(AppRoutes.AppRoutes.profile),
          ),
        ],
      ),
      body: Obx(
        () {
          final user = _authController.currentUser.value;

          if (user == null) {
            return const LoadingWidget();
          }

          if (_loadedUserId != user.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshData(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                InDriveCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: Text(
                          user.nomComplet.substring(0, 1).toUpperCase(),
                          style: AppTextStyles.h3.copyWith(color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${'hello'.tr}, ${user.nomComplet}',
                              style: AppTextStyles.h3,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'welcome_client'.tr,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      InDriveButton(
                        label: 'create_request'.tr,
                        onPressed: () => Get.toNamed(AppRoutes.AppRoutes.categories),
                        height: 46,
                        variant: InDriveButtonVariant.secondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                InDriveSectionTitle(
                  title: 'my_requests'.tr,
                  subtitle: 'request_in_progress'.tr,
                  actionText: 'refresh'.tr,
                  onActionTap: _refreshData,
                ),
                const SizedBox(height: 16),
                Obx(
                  () {
                    if (_requestController.isLoading.value) {
                      return const LoadingWidget();
                    }

                    final visibleRequests = _requestController.requests
                        .where((request) {
                          final status = request.statut.toLowerCase();
                          return status != 'cancelled' && status != 'completed';
                        })
                        .toList();

                    if (visibleRequests.isEmpty) {
                      return EmptyState(
                        icon: Icons.request_quote_outlined,
                        title: 'no_requests'.tr,
                        message: 'no_requests_message'.tr,
                      );
                    }

                    return ListView.separated(
                      itemCount: visibleRequests.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final request = visibleRequests[index];
                        final isActive = request.statut.toLowerCase() == 'pending' ||
                            request.statut.toLowerCase() == 'accepted';

                        return InDriveCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(request.statut).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _getStatusText(request.statut),
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: _getStatusColor(request.statut),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () async {
                                      _requestController.selectRequest(request);
                                      final result = await Get.toNamed(
                                        AppRoutes.AppRoutes.requestDetail,
                                        arguments: request.id,
                                      );
                                      if (result == true && mounted) {
                                        _refreshData();
                                      }
                                    },
                                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '#${request.id.substring(0, 8)}',
                                style: AppTextStyles.h4,
                              ),
                              const SizedBox(height: 8),
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
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
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
                              if (isActive) ...[
                                const SizedBox(height: 14),
                                InDriveButton(
                                  label: 'cancel_request'.tr,
                                  onPressed: _requestController.isLoading.value
                                      ? null
                                      : () => _showCancelRequestDialog(context, request),
                                  variant: InDriveButtonVariant.ghost,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.info;
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
      case 'pending':
        return 'status_pending'.tr;
      case 'accepted':
        return 'status_accepted'.tr;
      case 'completed':
        return 'status_completed'.tr;
      case 'cancelled':
        return 'status_cancelled'.tr;
      default:
        return statut;
    }
  }


  void _showCancelRequestDialog(BuildContext context, RequestModel request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Obx(
        () => InDriveDialogTemplate(
          title: 'cancel_request_dialog_title'.tr,
          message: 'cancel_request_dialog_content'.tr,
          primaryLabel: _requestController.isLoading.value ? 'loading'.tr : 'yes_cancel'.tr,
          onPrimary: _requestController.isLoading.value
              ? () {}
              : () async {
                  final success = await _requestController.cancelRequest(request.id);
                  if (success && context.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
          secondaryLabel: 'no'.tr,
          onSecondary: _requestController.isLoading.value
              ? null
              : () => Navigator.of(dialogContext).pop(),
          danger: true,
        ),
      ),
    );
  }
}
