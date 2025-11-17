import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../controllers/request_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import 'notification_screen.dart';
import 'history_screen.dart';

/// Dashboard Employee with Bottom Navigation
class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  int _currentIndex = 1; // Default to Home (middle)
  final RequestController _requestController = Get.put(RequestController());
  final AuthController _authController = Get.find<AuthController>();
  final EmployeeController _employeeController = Get.put(EmployeeController());
  String? _loadedUserId;
  String? _currentCategorieId;

  final List<Widget> _screens = [
    const NotificationScreen(),
    const _EmployeeHomeScreen(),
    const HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStreaming();
    });
  }
  
  @override
  void dispose() {
    // Don't stop streaming here - keep it active even when navigating away
    // The stream will be stopped when user logs out or app closes
    super.dispose();
  }

  Future<void> _initializeStreaming() async {
    final user = _authController.currentUser.value;
    if (user == null) return;
    
    // Check if we need to restart the stream
    final needsRestart = _loadedUserId != user.id || _currentCategorieId == null;
    
    if (!needsRestart) {
      debugPrint('[EmployeeDashboard] Stream already active for user ${user.id}');
      return; // Already initialized
    }

    try {
      debugPrint('[EmployeeDashboard] Initializing stream for user: ${user.id}');
      _loadedUserId = user.id;
      final employee = await _employeeController.getEmployeeByUserId(user.id);
      if (employee != null) {
        _currentCategorieId = employee.categorieId;
        // Start streaming to get real-time updates for badge count
        // This stream will stay active even when navigating between screens
        // Load initial data first, then start stream
        // Pass employee document ID so notification count can exclude dealt requests
        await _requestController.streamRequestsByCategorie(
          employee.categorieId,
          employeeDocumentId: employee.id,
        );
        debugPrint('[EmployeeDashboard] Stream started for category: ${employee.categorieId}, Employee ID: ${employee.id}');
      }
    } catch (e) {
      debugPrint('[EmployeeDashboard] Error initializing stream: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Obx(
        () {
          // Ensure stream is active when user changes
          final user = _authController.currentUser.value;
          if (user != null && (_loadedUserId != user.id || _currentCategorieId == null)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initializeStreaming();
            });
          }
          
          // Get notification count from controller
          final notificationCount = _requestController.notificationCount;
          
          return BottomNavigationBar(
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
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (notificationCount > 0)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            notificationCount > 99 ? '99+' : notificationCount.toString(),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                activeIcon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications),
                    if (notificationCount > 0)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            notificationCount > 99 ? '99+' : notificationCount.toString(),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'notifications'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home),
                label: 'home'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.history_outlined),
                activeIcon: const Icon(Icons.history),
                label: 'history'.tr,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Home screen content for Employee
class _EmployeeHomeScreen extends StatefulWidget {
  const _EmployeeHomeScreen();

  @override
  State<_EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<_EmployeeHomeScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final MissionController _missionController = Get.put(MissionController());
  final EmployeeController _employeeController = Get.put(EmployeeController());
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMissions();
    });
  }

  Future<void> _loadMissions() async {
    final user = _authController.currentUser.value;
    if (user == null || _loadedUserId == user.id) return;

    try {
      // Get employee document ID from user ID
      final employee = await _employeeController.getEmployeeByUserId(user.id);
      if (employee != null) {
        _loadedUserId = user.id;
        // Stream missions using employee document ID for real-time updates
        await _missionController.streamMissionsByEmployee(employee.id);
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord Employé'),
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
              _loadMissions();
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
                          'welcome_employee'.tr,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),



                // Missions Section
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
                        title: 'no_missions'.tr,
                        message: 'no_missions_message'.tr,
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
                            title: Text('${'mission'.tr} #${mission.id.substring(0, 8)}'),
                            subtitle: Text(
                              '${'mission_price'.tr}: ${mission.prixMission.toStringAsFixed(2)} €\n'
                              '${'mission_status'.tr}: ${_getStatusText(mission.statutMission)}\n'
                              '${'mission_date'.tr}: ${mission.dateStart.toString().substring(0, 10)}',
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
                                _getStatusText(mission.statutMission),
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

  String _getStatusText(String statut) {
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
