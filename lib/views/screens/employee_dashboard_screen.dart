import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../controllers/request_controller.dart';
import '../../data/models/mission_model.dart';
import '../../data/repositories/employee_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../core/services/location_service.dart' show LocationService, LocationException;
import '../../core/helpers/snackbar_helper.dart';
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import '../../components/app_sidebar.dart';
import '../../components/language_switcher.dart';
import '../../components/indrive_app_bar.dart';
import '../../components/indrive_card.dart';
import '../../components/indrive_section_title.dart';
import '../../components/indrive_button.dart';
import 'notification_screen.dart';
import 'chat_screen.dart';
import '../../widgets/call_button.dart';

/// Dashboard Employee
class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final RequestController _requestController = Get.put(RequestController());
  final AuthController _authController = Get.find<AuthController>();
  final EmployeeController _employeeController = Get.put(EmployeeController());
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final LocationService _locationService = LocationService();
  String? _loadedUserId;
  String? _currentCategorieId;
  bool _locationUpdateAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStreaming();
      _updateEmployeeLocation();
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

  /// Mettre à jour la localisation GPS de l'employé
  Future<void> _updateEmployeeLocation() async {
    // Ne mettre à jour qu'une seule fois par session
    if (_locationUpdateAttempted) return;
    
    final user = _authController.currentUser.value;
    if (user == null || user.type.toLowerCase() != 'employee') return;
    
    _locationUpdateAttempted = true;
    
    try {
      // Vérifier si le GPS est activé
      final isGpsEnabled = await _locationService.isLocationServiceEnabled();
      if (!isGpsEnabled) {
        debugPrint('[EmployeeDashboard] GPS désactivé, impossible de mettre à jour la localisation');
        // Afficher une boîte de dialogue pour demander d'activer le GPS
        await _showGpsDisabledDialog();
        return;
      }
      
      // Vérifier et demander les permissions
      try {
        await _locationService.requestLocationPermission();
      } catch (e) {
        debugPrint('[EmployeeDashboard] Permissions de localisation non accordées: $e');
        // Si c'est une LocationException, afficher la boîte de dialogue
        if (e is LocationException && e.canOpenSettings) {
          await _showLocationErrorDialog(e.message);
        }
        return;
      }
      
      // Obtenir la localisation
      final locationData = await _locationService.getCurrentLocationWithAddress();
      
      final latitude = locationData['latitude'] as double;
      final longitude = locationData['longitude'] as double;
      
      // Récupérer l'employé
      final employee = await _employeeRepository.getEmployeeByUserId(user.id);
      if (employee != null) {
        // Mettre à jour la localisation GPS
        final updatedEmployee = employee.copyWith(
          latitude: latitude,
          longitude: longitude,
          updatedAt: DateTime.now(),
        );
        
        await _employeeRepository.updateEmployee(updatedEmployee);
        debugPrint('[EmployeeDashboard] Localisation GPS de l\'employé mise à jour: $latitude, $longitude');
      }
    } catch (e) {
      debugPrint('[EmployeeDashboard] Erreur lors de la mise à jour de la localisation GPS: $e');
      // Ne pas bloquer si la localisation échoue
    }
  }

  /// Afficher une boîte de dialogue si le GPS est désactivé
  Future<void> _showGpsDisabledDialog() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text('location_required_title'.tr),
        content: Text('location_gps_disabled'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: Text('open_settings'.tr),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _locationService.openLocationSettings();
    }
  }

  /// Afficher une boîte de dialogue pour les erreurs de localisation
  Future<void> _showLocationErrorDialog(String message) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text('location_required_title'.tr),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: Text('open_settings'.tr),
          ),
        ],
      ),
    );
    
    if (result == true) {
      // Vérifier si le GPS est désactivé, puis ouvrir les paramètres appropriés
      final isGpsEnabled = await _locationService.isLocationServiceEnabled();
      if (!isGpsEnabled) {
        await _locationService.openLocationSettings();
      } else {
        await _locationService.openAppSettings();
      }
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

    return const _EmployeeHomeScreen();
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
  String? _currentEmployeeDocumentId;

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
        _currentEmployeeDocumentId = employee.id;
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
      backgroundColor: AppColors.night,
      drawer: const AppSidebar(),
      appBar: InDriveAppBar(
        title: 'employee_dashboard'.tr,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          // Notification icon with badge
          Obx(
            () {
              final user = _authController.currentUser.value;
              final requestsList = _requestController.requests;
              
              // Get employee document ID - use cached value if available
              String? employeeDocumentId = _currentEmployeeDocumentId;
              
              // If not loaded, try to get from RequestController cache or load it
              if (employeeDocumentId == null && user != null) {
                // RequestController should have it cached from stream initialization
                // We'll load it in background for next rebuild
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  final employee = await _employeeController.getEmployeeByUserId(user.id);
                  if (employee != null && mounted) {
                    setState(() {
                      _currentEmployeeDocumentId = employee.id;
                    });
                  }
                });
              }
              
              final notificationCount = requestsList.where((request) {
                // Only count pending requests
                if (request.statut.toLowerCase() != 'pending') return false;
                // Don't count own requests
                if (user != null && request.clientId == user.id) return false;
                // Don't count requests that employee has already accepted
                if (employeeDocumentId != null && 
                    request.acceptedEmployeeIds.contains(employeeDocumentId)) {
                  return false;
                }
                // Don't count requests that employee has already refused
                if (employeeDocumentId != null && 
                    request.refusedEmployeeIds.contains(employeeDocumentId)) {
                  return false;
                }
                return true;
              }).length;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      color: Colors.white,
                      onPressed: () {
                        Get.to(() => const NotificationScreen());
                      },
                    ),
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.error,
                              AppColors.error.withOpacity(0.8),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
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
              );
            },
          ),
          const SizedBox(width: 8),
          const LanguageSwitcher(),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Obx(
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Card moderne
                InDriveCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                user.nomComplet.isNotEmpty ? user.nomComplet[0].toUpperCase() : 'E',
                                style: AppTextStyles.h2.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${'hello'.tr}, ${user.nomComplet}',
                                  style: AppTextStyles.h3.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'welcome_employee'.tr,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Missions Section
                InDriveSectionTitle(
                  title: 'my_missions'.tr,
                  subtitle: 'Vos missions actives',
                  icon: Icons.work_rounded,
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

                    // Filter only active missions (not completed or cancelled)
                    final activeMissions = _missionController.missions.where((mission) {
                      final status = mission.statutMission.toLowerCase();
                      return status != 'completed' && status != 'cancelled';
                    }).toList();

                    if (activeMissions.isEmpty) {
                      return EmptyState(
                        icon: Icons.work_outline,
                        title: 'no_missions'.tr,
                        message: 'no_missions_message'.tr,
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activeMissions.length,
                      itemBuilder: (context, index) {
                        final mission = activeMissions[index];
                        final canChat = mission.requestId != null &&
                            mission.statutMission.toLowerCase() != 'completed';
                        final statusColor = _getStatusColor(mission.statutMission);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: InDriveCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header avec ID et statut
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  Icons.work_rounded,
                                                  color: AppColors.primaryLight,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  '${'mission'.tr} #${mission.id.substring(0, 8)}',
                                                  style: AppTextStyles.h4.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          // Prix
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.attach_money_rounded,
                                                size: 18,
                                                color: AppColors.success,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${mission.prixMission.toStringAsFixed(2)} DH',
                                                style: AppTextStyles.bodyLarge.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Date
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today_rounded,
                                                size: 16,
                                                color: Colors.white54,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                mission.dateStart.toString().substring(0, 10),
                                                style: AppTextStyles.bodyMedium.copyWith(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Badge de statut
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            statusColor,
                                            statusColor.withOpacity(0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.3),
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _getStatusText(mission.statutMission),
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Actions
                                if (canChat)
                                  Row(
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
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppColors.primary.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: TextButton.icon(
                                          onPressed: () => _openChatFromMission(mission),
                                          icon: Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            color: AppColors.primaryLight,
                                            size: 18,
                                          ),
                                          label: Text(
                                            'open_chat'.tr,
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              color: AppColors.primaryLight,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                // QR Scanner button for employee (shown if mission is not completed)
                                if (mission.statutMission.toLowerCase() != 'completed') ...[
                                  const SizedBox(height: 12),
                                  InDriveButton(
                                    label: 'scan_qr_to_approve'.tr,
                                    onPressed: _openQRScanner,
                                    variant: InDriveButtonVariant.secondary,
                                    leadingIcon: Icons.qr_code_scanner_rounded,
                                  ),
                                ],
                              ],
                            ),
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
