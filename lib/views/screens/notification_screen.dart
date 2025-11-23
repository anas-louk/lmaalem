import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/request_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../data/models/request_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/empty_state.dart';
import '../../components/loading_widget.dart';
import '../../core/helpers/snackbar_helper.dart';

/// Écran de notifications pour les employés
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final RequestController _requestController = Get.put(RequestController());
  final EmployeeController _employeeController = Get.put(EmployeeController());
  String? _loadedUserId;
  String? _currentEmployeeDocumentId;
  String? _currentCategorieId;

  @override
  void initState() {
    super.initState();
    // Stream is already initialized at dashboard level
    // Just ensure we have the employee data for filtering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmployeeData();
    });
  }
  
  @override
  void dispose() {
    // Don't stop streaming here - it's managed at dashboard level
    super.dispose();
  }

  Future<void> _loadEmployeeData() async {
    final user = _authController.currentUser.value;
    if (user == null) return;
    
    // Only load employee data if not already loaded
    if (_currentEmployeeDocumentId != null && _loadedUserId == user.id) {
      return;
    }

    try {
      final employee = await _employeeController.getEmployeeByUserId(user.id);
      if (employee != null) {
        _loadedUserId = user.id;
        _currentEmployeeDocumentId = employee.id;
        _currentCategorieId = employee.categorieId;
        
        // Set employee document ID in controller for notification count
        _requestController.setEmployeeDocumentId(employee.id);
        
        debugPrint('[NotificationScreen] Loaded employee data: ID=${employee.id}, Category=${employee.categorieId}');
      }
    } catch (e) {
      debugPrint('[NotificationScreen] Error loading employee data: $e');
    }
  }
  
  Future<void> _refreshRequests() async {
    // Refresh by restarting the stream at dashboard level
    final user = _authController.currentUser.value;
    if (user == null) return;
    
    final employee = await _employeeController.getEmployeeByUserId(user.id);
    if (employee != null) {
      // Restart stream - this will be handled by the controller
      _requestController.stopStreaming();
      await Future.delayed(const Duration(milliseconds: 100));
      await _requestController.streamRequestsByCategorie(
        employee.categorieId,
        employeeDocumentId: employee.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'notifications'.tr,
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      body: Obx(
        () {
          // Access user first to ensure reactivity
          final user = _authController.currentUser.value;

          if (user == null) {
            return const LoadingWidget();
          }

          // Ensure employee data is loaded
          if (_loadedUserId != user.id || _currentCategorieId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadEmployeeData();
            });
          }
          
          // Ensure stream is active (it should be started at dashboard level)
          // But verify it's running for the current category
          if (_currentCategorieId != null) {
            final currentCategory = _currentCategorieId;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              // Only start stream if not already active for this category
              // The dashboard should have started it, but this is a safety check
              if (_requestController.requests.isEmpty && !_requestController.isLoading.value && !_requestController.hasReceivedFirstData.value) {
                await _requestController.streamRequestsByCategorie(
                  currentCategory!,
                  employeeDocumentId: _currentEmployeeDocumentId,
                );
              }
            });
          }

          // Access RxList directly - GetX tracks all changes
          // Accessing .length triggers reactivity - store it in a variable
          final requestsList = _requestController.requests;
          final requestsLength = requestsList.length; // This triggers reactivity
          final isLoading = _requestController.isLoading.value;
          final hasReceivedFirstData = _requestController.hasReceivedFirstData.value;
          
          // Show loading if we haven't received first data yet OR if loading and no data
          if ((!hasReceivedFirstData && requestsLength == 0) || (isLoading && requestsLength == 0 && !hasReceivedFirstData)) {
            return const LoadingWidget();
          }

          // Filter requests - only exclude own requests
          // Keep showing accepted/refused requests, but they won't count in notification counter
          final filteredRequests = <RequestModel>[];
          for (var i = 0; i < requestsLength; i++) {
            final request = requestsList[i];
            
            // Only show pending requests
            if (request.statut.toLowerCase() != 'pending') continue;
            
            // Don't show own requests
            if (request.clientId == user.id) continue;
            
            // Show all requests (including accepted/refused) - they just won't count in badge
            filteredRequests.add(request);
          }
          
          // Debug log to verify updates
          debugPrint('[NotificationScreen] Build: Filtered=${filteredRequests.length}, Total=$requestsLength, Loading=$isLoading');

          if (filteredRequests.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshRequests,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: EmptyState(
                    icon: Icons.notifications_none,
                    title: 'no_notifications'.tr,
                    message: 'no_notifications_message'.tr,
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshRequests,
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredRequests.length,
              itemBuilder: (context, index) {
              final request = filteredRequests[index];
              final isAccepted = _isRequestAccepted(request);
              final isRefused = _isRequestRefused(request);
              final isRefusedByClient = _isRequestRefusedByClient(request);
              debugPrint('[NotificationScreen] Request ${request.id}: isAccepted=$isAccepted, isRefused=$isRefused, isRefusedByClient=$isRefusedByClient');
              return _buildNotificationCard(context, request, isAccepted, isRefused, isRefusedByClient, index);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    RequestModel request,
    bool isAccepted,
    bool isRefused,
    bool isRefusedByClient,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _requestController.selectRequest(request);
              Get.toNamed(
                AppRoutes.AppRoutes.requestDetail,
                arguments: request.id,
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Row(
                    children: [
                      // Icon Container
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.15),
                              AppColors.primaryLight.withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.work_outline,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title and ID
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'new_request'.tr,
                              style: AppTextStyles.h4.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.tag,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${'request'.tr} #${request.id.substring(0, 8)}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.warning,
                              AppColors.warning.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.warning.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'pending'.tr,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.greyLight,
                          AppColors.greyLight.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Description
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.greyLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            request.description,
                            style: AppTextStyles.bodyMedium.copyWith(
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Location and Images Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          icon: Icons.location_on_rounded,
                          text: request.address,
                          color: AppColors.error,
                        ),
                      ),
                      if (request.images.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          icon: Icons.image_rounded,
                          text: '${request.images.length}',
                          color: AppColors.info,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Time Info
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${'created_on'.tr} ${_formatDate(request.createdAt)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Waiting Banner (if accepted)
                  if (isAccepted) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.info.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hourglass_empty_rounded,
                              color: AppColors.info,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'waiting_for_client'.tr,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.info,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'waiting_for_client_message'.tr,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Show refused message if employee refused or client refused, otherwise show action buttons
                  Obx(() {
                    // Get the latest request from the reactive list to ensure we have the most up-to-date data
                    final latestRequest = _requestController.requests.firstWhere(
                      (r) => r.id == request.id,
                      orElse: () => request,
                    );
                    
                    // Recalculate these values reactively inside Obx to ensure updates
                    final currentIsRefused = _isRequestRefused(latestRequest);
                    final currentIsRefusedByClient = _isRequestRefusedByClient(latestRequest);
                    final currentIsAccepted = _isRequestAccepted(latestRequest);
                    
                    if (currentIsRefused || currentIsRefusedByClient) {
                      // Refused Message
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: AppColors.error,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                currentIsRefusedByClient ? 'client_refused_request'.tr : 'you_refused_request'.tr,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // Action Buttons
                      return Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context: context,
                              label: currentIsAccepted ? 'cancel_acceptance'.tr : 'refuse'.tr,
                              icon: currentIsAccepted ? Icons.cancel_outlined : Icons.close_rounded,
                              color: AppColors.error,
                              onPressed: _requestController.isLoading.value
                                  ? null
                                  : () => currentIsAccepted
                                      ? _cancelAcceptance(request.id)
                                      : _refuseRequest(request.id),
                              isLoading: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildActionButton(
                              context: context,
                              label: currentIsAccepted ? 'waiting_for_client'.tr : 'accept'.tr,
                              icon: currentIsAccepted ? Icons.hourglass_empty_rounded : Icons.check_rounded,
                              color: currentIsAccepted ? AppColors.info : AppColors.success,
                              onPressed: currentIsAccepted || _requestController.isLoading.value
                                  ? null
                                  : () => _acceptRequest(request.id),
                              isLoading: _requestController.isLoading.value,
                              isPrimary: true,
                            ),
                          ),
                        ],
                      );
                    }
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required bool isLoading,
    bool isPrimary = false,
  }) {
    if (isPrimary) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: onPressed == null
                ? [AppColors.grey, AppColors.grey]
                : [
                    color,
                    color.withOpacity(0.8),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            style: AppTextStyles.buttonMedium.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    } else {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.buttonMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }

  bool _isRequestAccepted(RequestModel request) {
    if (_currentEmployeeDocumentId == null) return false;
    return request.acceptedEmployeeIds.contains(_currentEmployeeDocumentId);
  }

  bool _isRequestRefused(RequestModel request) {
    if (_currentEmployeeDocumentId == null) return false;
    return request.refusedEmployeeIds.contains(_currentEmployeeDocumentId);
  }

  bool _isRequestRefusedByClient(RequestModel request) {
    if (_currentEmployeeDocumentId == null) {
      debugPrint('[NotificationScreen] _isRequestRefusedByClient: _currentEmployeeDocumentId is null');
      return false;
    }
    final isRefused = request.clientRefusedEmployeeIds.contains(_currentEmployeeDocumentId);
    debugPrint('[NotificationScreen] _isRequestRefusedByClient: Request=${request.id}, EmployeeId=$_currentEmployeeDocumentId, ClientRefusedIds=${request.clientRefusedEmployeeIds}, Result=$isRefused');
    return isRefused;
  }

  Future<void> _acceptRequest(String requestId) async {
    final user = _authController.currentUser.value;
    if (user == null) return;

    await _requestController.acceptRequestByEmployee(requestId, user.id);
    // No need to reload - stream will update automatically
  }

  Future<void> _refuseRequest(String requestId) async {
    final user = _authController.currentUser.value;
    if (user == null) return;

    // Show confirmation dialog
    final shouldRefuse = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'refuse_request'.tr,
          style: AppTextStyles.h4,
        ),
        content: Text(
          'refuse_request_confirmation'.tr,
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'cancel'.tr,
              style: AppTextStyles.buttonMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );

    if (shouldRefuse == true) {
      await _requestController.refuseRequestByEmployee(requestId, user.id);
      SnackbarHelper.showSnackbar(
        title: 'success'.tr,
        message: 'request_refused_success'.tr,
        backgroundColor: AppColors.success.withOpacity(0.9),
        colorText: AppColors.white,
        position: SnackPosition.BOTTOM,
      );
      // No need to reload - stream will update automatically
    }
  }

  Future<void> _cancelAcceptance(String requestId) async {
    final user = _authController.currentUser.value;
    if (user == null) return;

    // Show confirmation dialog
    final shouldCancel = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'cancel_acceptance'.tr,
          style: AppTextStyles.h4,
        ),
        content: Text(
          'cancel_acceptance_confirmation'.tr,
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'cancel'.tr,
              style: AppTextStyles.buttonMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      await _requestController.refuseRequestByEmployee(requestId, user.id);
      SnackbarHelper.showSnackbar(
        title: 'success'.tr,
        message: 'acceptance_cancelled'.tr,
        backgroundColor: AppColors.success.withOpacity(0.9),
        colorText: AppColors.white,
        position: SnackPosition.BOTTOM,
      );
      // No need to reload - stream will update automatically
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

