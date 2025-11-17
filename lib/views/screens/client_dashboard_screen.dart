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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
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
      appBar: AppBar(
        title: Text('client_dashboard'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Get.toNamed(AppRoutes.AppRoutes.profile);
            },
          ),
        ],
      ),
      body: Obx(
        () {
          final user = _authController.currentUser.value;

          if (user == null) {
            return const LoadingWidget();
          }

          // Reload if user changes
          if (_loadedUserId != user.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadData();
            });
          }


          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '${'hello'.tr}, ${user.nomComplet}',
                          style: AppTextStyles.h2,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'welcome_client'.tr,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),


                // Requests Section
                Text(
                  'my_requests'.tr,
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 16),

                Obx(
                  () {
                    if (_requestController.isLoading.value) {
                      return const LoadingWidget();
                    }

                    if (_requestController.requests.isEmpty) {
                      return EmptyState(
                        icon: Icons.request_quote_outlined,
                        title: 'no_requests'.tr,
                        message: 'no_requests_message'.tr,
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _requestController.requests.length,
                      itemBuilder: (context, index) {
                        final request = _requestController.requests[index];
                        final isActive = request.statut.toLowerCase() == 'pending' || 
                                        request.statut.toLowerCase() == 'accepted';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(request.statut),
                                  child: Icon(
                                    _getStatusIcon(request.statut),
                                    color: AppColors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '${'request'.tr} #${request.id.substring(0, 8)}',
                                  style: AppTextStyles.h4,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      request.description,
                                      style: AppTextStyles.bodySmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            request.address,
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(request.statut),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStatusText(request.statut),
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                onTap: () async {
                                  _requestController.selectRequest(request);
                                  final result = await Get.toNamed(
                                    AppRoutes.AppRoutes.requestDetail,
                                    arguments: request.id,
                                  );
                                  // Refresh data when coming back from request detail
                                  if (result == true || mounted) {
                                    _refreshData();
                                  }
                                },
                              ),
                              // Cancel button for active requests
                              if (isActive)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Obx(
                                    () => SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _requestController.isLoading.value
                                            ? null
                                            : () => _showCancelRequestDialog(context, request),
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: Text('cancel_request'.tr),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          side: const BorderSide(color: AppColors.error),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Missions Section (Completed/Accepted requests)
                Text(
                  'my_missions'.tr,
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 16),

                Obx(
                  () {
                    final missionsLength = _missionController.missions.length;
                    final isLoading = _missionController.isLoading.value;
                    final hasReceivedFirstData = _missionController.hasReceivedFirstData.value;

                    // Show loading if we haven't received first data yet OR if loading and no data
                    if ((!hasReceivedFirstData && missionsLength == 0) || (isLoading && missionsLength == 0 && !hasReceivedFirstData)) {
                      return const LoadingWidget();
                    }

                    if (missionsLength == 0) {
                      return EmptyState(
                        icon: Icons.work_outline,
                        title: 'no_missions_client'.tr,
                        message: 'no_missions_client_message'.tr,
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _missionController.missions.length,
                      itemBuilder: (context, index) {
                        final mission = _missionController.missions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getMissionStatusColor(mission.statutMission),
                              child: Icon(
                                _getMissionStatusIcon(mission.statutMission),
                                color: AppColors.white,
                                size: 20,
                              ),
                            ),
                            title: Text('${'mission'.tr} #${mission.id.substring(0, 8)}'),
                            subtitle: Text(
                              '${'mission_price'.tr}: ${mission.prixMission.toStringAsFixed(2)} €\n'
                              '${'mission_status'.tr}: ${_getMissionStatusText(mission.statutMission)}',
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: AppColors.primary,
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

  IconData _getStatusIcon(String statut) {
    switch (statut.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
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

  IconData _getMissionStatusIcon(String statut) {
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

  void _showCancelRequestDialog(BuildContext context, RequestModel request) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (dialogContext) => Obx(
        () => AlertDialog(
          title: Text('cancel_request_dialog_title'.tr),
          content: Text('cancel_request_dialog_content'.tr),
          actions: [
            TextButton(
              onPressed: _requestController.isLoading.value
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop(); // Close dialog using Navigator
                    },
              child: Text('no'.tr),
            ),
            ElevatedButton(
              onPressed: _requestController.isLoading.value
                  ? null
                  : () async {
                      final success = await _requestController.cancelRequest(request.id);
                      if (success) {
                        Navigator.of(dialogContext).pop(); // Close dialog
                        // Stream will update automatically, no need to reload
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: _requestController.isLoading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                      ),
                    )
                  : Text('yes_cancel'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
