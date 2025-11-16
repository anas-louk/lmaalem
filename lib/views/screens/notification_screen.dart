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
import '../../components/custom_button.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStreaming();
    });
  }
  
  @override
  void dispose() {
    // Don't stop streaming here as it might be used by other screens
    // The controller will manage its own lifecycle
    super.dispose();
  }

  Future<void> _startStreaming() async {
    final user = _authController.currentUser.value;
    if (user == null) {
      debugPrint('[NotificationScreen] No user, skipping stream');
      return;
    }
    
    if (_loadedUserId == user.id && _currentCategorieId != null) {
      debugPrint('[NotificationScreen] Already streaming for user ${user.id}, skipping');
      return;
    }

    try {
      debugPrint('[NotificationScreen] Starting stream for user: ${user.id}');
      
      // Set loaded user ID early to prevent multiple calls
      _loadedUserId = user.id;
      
      // Get employee data to find their category and document ID
      final employee = await _employeeController.getEmployeeByUserId(user.id);
      if (employee != null) {
        _currentEmployeeDocumentId = employee.id;
        _currentCategorieId = employee.categorieId;
        
        // Debug: Log category ID
        debugPrint('[NotificationScreen] Employee category ID: ${employee.categorieId}, Employee ID: ${employee.id}');
        
        // Start real-time streaming for this category
        _requestController.streamRequestsByCategorie(employee.categorieId);
        
        debugPrint('[NotificationScreen] Started streaming requests for category: ${employee.categorieId}');
      } else {
        debugPrint('[NotificationScreen] Employee not found for user: ${user.id}');
      }
    } catch (e, stackTrace) {
      debugPrint('[NotificationScreen] Error starting stream: $e');
      debugPrint('[NotificationScreen] StackTrace: $stackTrace');
    }
  }
  
  Future<void> _refreshRequests() async {
    // Refresh by restarting the stream
    final user = _authController.currentUser.value;
    if (user == null) return;
    
    final employee = await _employeeController.getEmployeeByUserId(user.id);
    if (employee != null) {
      _currentCategorieId = null; // Reset to force restart
      _startStreaming();
    }
  }

  List<RequestModel> _getFilteredRequests() {
    final user = _authController.currentUser.value;
    if (user == null) return [];

    // Filter out requests where clientId matches the employee's userId
    // and only show pending requests
    return _requestController.requests.where((request) {
      return request.statut.toLowerCase() == 'pending' &&
             request.clientId != user.id; // Don't show own requests
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('notifications'.tr),
      ),
      body: Obx(
        () {
          final user = _authController.currentUser.value;

          if (user == null) {
            return const LoadingWidget();
          }

          // Restart stream if user changes
          if (_loadedUserId != user.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startStreaming();
            });
          }

          if (_requestController.isLoading.value) {
            return const LoadingWidget();
          }

          final filteredRequests = _getFilteredRequests();

          if (filteredRequests.isEmpty) {
            return Center(
              child: EmptyState(
                icon: Icons.notifications_none,
                title: 'no_notifications'.tr,
                message: 'no_notifications_message'.tr,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshRequests,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredRequests.length,
              itemBuilder: (context, index) {
                final request = filteredRequests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      _requestController.selectRequest(request);
                      Get.toNamed(
                        AppRoutes.AppRoutes.requestDetail,
                        arguments: request.id,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.request_quote,
                                  color: AppColors.warning,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'new_request'.tr,
                                      style: AppTextStyles.h4.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${'request'.tr} #${request.id.substring(0, 8)}',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'pending'.tr,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            request.description,
                            style: AppTextStyles.bodyMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
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
                          if (request.images.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.image,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${request.images.length} image${request.images.length > 1 ? 's' : ''}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '${'created_on'.tr} ${_formatDate(request.createdAt)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Accept/Refuse buttons for employees
                          Row(
                            children: [
                              Expanded(
                                child: Obx(
                                  () => OutlinedButton(
                                    onPressed: _requestController.isLoading.value
                                        ? null
                                        : () => _refuseRequest(request.id),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(color: AppColors.error),
                                    ),
                                    child: Text('refuse'.tr),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Obx(
                                  () => CustomButton(
                                    onPressed: _requestController.isLoading.value
                                        ? null
                                        : () => _acceptRequest(request.id),
                                    text: _isRequestAccepted(request)
                                        ? 'accepted'.tr
                                        : 'accept'.tr,
                                    isLoading: _requestController.isLoading.value,
                                    backgroundColor: AppColors.success,
                                    height: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  bool _isRequestAccepted(RequestModel request) {
    if (_currentEmployeeDocumentId == null) return false;
    return request.acceptedEmployeeIds.contains(_currentEmployeeDocumentId);
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

    await _requestController.refuseRequestByEmployee(requestId, user.id);
    // No need to reload - stream will update automatically
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

