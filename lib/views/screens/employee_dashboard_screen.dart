import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../controllers/request_controller.dart';
import '../../data/models/mission_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../core/helpers/snackbar_helper.dart';
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import '../../components/app_sidebar.dart';
import '../../components/language_switcher.dart';
import 'notification_screen.dart';
import 'history_screen.dart';
import 'chat_screen.dart';
import '../../widgets/call_button.dart';

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
    // Ensure stream is active when user changes
    final user = _authController.currentUser.value;
    if (user != null && (_loadedUserId != user.id || _currentCategorieId == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeStreaming();
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
  final RequestController _requestController = Get.find<RequestController>();
  String? _loadedUserId;

  void _openQRScanner() async {
    final result = await Get.toNamed(AppRoutes.AppRoutes.qrScanner);
    if (result == true) {
      // Reload missions if QR code was successfully scanned
      _loadMissions();
      SnackbarHelper.showSuccess('request_completed_success'.tr);
    }
  }

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

  Future<String?> _getClientIdFromMission(MissionModel mission) async {
    if (mission.requestId == null) return null;
    
    try {
      final request = await _requestController.getRequestById(mission.requestId!);
      if (request == null ||
          request.statut.toLowerCase() != 'accepted') {
        return null;
      }
      return request.clientId;
    } catch (e) {
      return null;
    }
  }

  Future<void> _openChatFromMission(MissionModel mission) async {
    if (mission.requestId == null) {
      SnackbarHelper.showInfo('chat_not_available'.tr);
      return;
    }

    final request = await _requestController.getRequestById(mission.requestId!);
    if (request == null ||
        request.employeeId == null ||
        request.statut.toLowerCase() != 'accepted') {
      SnackbarHelper.showInfo('chat_not_available'.tr);
      return;
    }

    Get.toNamed(
      AppRoutes.AppRoutes.chat,
      arguments: ChatScreenArguments(
        requestId: request.id,
        clientId: request.clientId,
        employeeId: request.employeeId!,
        requestTitle: '${'request'.tr} #${request.id.substring(0, 8)}',
        requestStatus: request.statut,
        employeeName: _authController.currentUser.value?.nomComplet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppSidebar(),
      appBar: AppBar(
        title: const Text('Tableau de bord Employé'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: const [
          LanguageSwitcher(),
          SizedBox(width: 8),
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
                        final canChat = mission.requestId != null &&
                            mission.statutMission.toLowerCase() != 'completed';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            children: [
                              ListTile(
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
                              if (canChat)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Call buttons
                                      FutureBuilder<String?>(
                                        future: _getClientIdFromMission(mission),
                                        builder: (context, snapshot) {
                                          final clientId = snapshot.data;
                                          if (clientId == null || clientId.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Audio Call Button
                                              CallButton(
                                                calleeId: clientId,
                                                video: false,
                                                iconColor: AppColors.success,
                                                iconSize: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              // Video Call Button
                                              CallButton(
                                                calleeId: clientId,
                                                video: true,
                                                iconColor: AppColors.primary,
                                                iconSize: 20,
                                              ),
                                              const SizedBox(width: 12),
                                            ],
                                          );
                                        },
                                      ),
                                      // Chat Button
                                      TextButton.icon(
                                        onPressed: () => _openChatFromMission(mission),
                                        icon: const Icon(Icons.chat_bubble_outline),
                                        label: Text('open_chat'.tr),
                                      ),
                                    ],
                                  ),
                                ),
                              // QR Scanner button for employee (shown if mission is not completed)
                              if (mission.statutMission.toLowerCase() != 'completed')
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed: _openQRScanner,
                                      icon: const Icon(Icons.qr_code_scanner),
                                      label: Text('scan_qr_to_approve'.tr),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.warning,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
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
