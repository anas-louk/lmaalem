import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../../controllers/request_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../data/models/request_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/mission_model.dart';
import '../../data/models/client_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/mission_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/custom_button.dart';
import '../../core/utils/logger.dart';
import '../../core/helpers/snackbar_helper.dart';
import '../../widgets/call_button.dart';
import '../../core/services/qr_code_service.dart';
import '../../core/services/employee_statistics_service.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/distance_calculator.dart';
import '../../widgets/employee_statistics_widget.dart';
import '../../data/models/employee_statistics.dart';
import 'chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Écran de détails d'une demande
class RequestDetailScreen extends StatefulWidget {
  final String requestId;

  const RequestDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final RequestController _requestController = Get.put(RequestController());
  final AuthController _authController = Get.find<AuthController>();
  final EmployeeController _employeeController = Get.put(EmployeeController());
  final MissionController _missionController = Get.put(MissionController());
  final ClientRepository _clientRepository = ClientRepository();
  final MissionRepository _missionRepository = MissionRepository();
  final RequestRepository _requestRepository = RequestRepository();
  final QRCodeService _qrCodeService = QRCodeService();
  
  RequestModel? _request;
  bool _isLoading = true;
  List<EmployeeModel> _acceptedEmployees = [];
  MissionModel? _mission;
  EmployeeModel? _assignedEmployee;
  StreamSubscription<RequestModel?>? _requestStreamSubscription;
  Set<String> _previousAcceptedEmployeeIds = {}; // Track previous accepted employees
  final EmployeeStatisticsService _statisticsService = EmployeeStatisticsService();
  final Map<String, EmployeeStatistics> _employeeStatistics = {}; // Cache des statistiques
  final Map<String, double> _employeeDistances = {}; // Distance en km pour chaque employé

  @override
  void initState() {
    super.initState();
    _startStreaming();
  }

  @override
  void dispose() {
    _requestStreamSubscription?.cancel();
    super.dispose();
  }

  void _startStreaming() {
    // Load initial data first
    _loadRequest();
    
    // Then start streaming for real-time updates
    _requestStreamSubscription = _requestRepository.streamRequest(widget.requestId).listen(
      (request) {
        if (request != null) {
          setState(() {
            _request = request;
            _isLoading = false;
          });
          
          // Note: Employee acceptance notifications are handled globally in RequestController
          // No need to handle them here to avoid duplicates
          
          // Load accepted employees if the list changed
          if (request.acceptedEmployeeIds.isNotEmpty) {
            final newAcceptedIds = request.acceptedEmployeeIds.toSet();
            if (newAcceptedIds != _previousAcceptedEmployeeIds) {
              _previousAcceptedEmployeeIds = newAcceptedIds;
              _loadAcceptedEmployees(request.acceptedEmployeeIds);
            }
          } else {
            setState(() {
              _acceptedEmployees = [];
            });
            _previousAcceptedEmployeeIds.clear();
          }
          
          // Load mission if request is accepted
          if (request.statut.toLowerCase() == 'accepted' && request.employeeId != null) {
            _loadMission(request);
          _loadAssignedEmployee(request.employeeId!);
          } else {
            setState(() {
              _mission = null;
            _assignedEmployee = null;
            });
          }
        }
      },
      onError: (error) {
        Logger.logError('RequestDetailScreen._startStreaming', error, StackTrace.current);
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _loadRequest() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final request = await _requestController.getRequestById(widget.requestId);
      if (request != null) {
        _request = request;
        
        // Load accepted employees
        if (request.acceptedEmployeeIds.isNotEmpty) {
          await _loadAcceptedEmployees(request.acceptedEmployeeIds);
        }
        
        // Load mission if request is accepted
        if (request.statut.toLowerCase() == 'accepted' && request.employeeId != null) {
          await _loadMission(request);
          await _loadAssignedEmployee(request.employeeId!);
        } else {
          setState(() {
            _assignedEmployee = null;
          });
        }
      }
    } catch (e) {
      SnackbarHelper.showError( '${'error_loading'.tr}: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAcceptedEmployees(List<String> employeeIds) async {
    try {
      final employees = <EmployeeModel>[];
      // Filter out client-refused employees
      final filteredIds = employeeIds.where((id) => 
        _request?.clientRefusedEmployeeIds.contains(id) != true
      ).toList();
      
      for (final employeeId in filteredIds) {
        final employee = await _employeeController.getEmployeeById(employeeId);
        if (employee != null) {
          employees.add(employee);
          // Load statistics for this employee
          if (!_employeeStatistics.containsKey(employeeId)) {
            final stats = await _statisticsService.getEmployeeStatisticsByStringId(employeeId);
            _employeeStatistics[employeeId] = stats;
          }
        }
      }
      
      // Trier les employés par distance (les plus proches en premier)
      if (_request != null && employees.isNotEmpty) {
        final sortedEmployees = await _sortEmployeesByDistance(
          employees,
          _request!.latitude,
          _request!.longitude,
        );
        setState(() {
          _acceptedEmployees = sortedEmployees;
        });
      } else {
        setState(() {
          _acceptedEmployees = employees;
        });
      }
    } catch (e) {
      // Handle error
      setState(() {
        _acceptedEmployees = [];
      });
    }
  }
  
  /// Trier les employés par distance par rapport à la localisation du client
  Future<List<EmployeeModel>> _sortEmployeesByDistance(
    List<EmployeeModel> employees,
    double clientLat,
    double clientLon,
  ) async {
    if (employees.isEmpty || _request == null) return employees;

    final locationService = LocationService();
    final employeesWithDistance = <MapEntry<EmployeeModel, double>>[];

    for (final employee in employees) {
      try {
        double? employeeLat;
        double? employeeLon;
        
        // Priorité 1: Utiliser les coordonnées GPS stockées dans acceptedEmployeeLocations (localisation au moment de l'acceptation)
        if (_request!.acceptedEmployeeLocations.containsKey(employee.id)) {
          final location = _request!.acceptedEmployeeLocations[employee.id]!;
          employeeLat = location['latitude'];
          employeeLon = location['longitude'];
          debugPrint('[RequestDetailScreen] Utilisation des coordonnées GPS de acceptedEmployeeLocations pour ${employee.nomComplet}');
        }
        // Priorité 2: Utiliser les coordonnées GPS stockées dans le document de l'employé (fallback)
        else if (employee.latitude != null && employee.longitude != null) {
          employeeLat = employee.latitude;
          employeeLon = employee.longitude;
          debugPrint('[RequestDetailScreen] Utilisation des coordonnées GPS du document employé pour ${employee.nomComplet}');
        }
        // Priorité 3: Géocoder la localisation de l'employé (dernier recours)
        else {
          final locationString = employee.ville.isNotEmpty 
              ? employee.ville 
              : employee.localisation;
          
          if (locationString.isNotEmpty) {
            final coordinates = await locationService.getCoordinatesFromAddress(locationString);
            if (coordinates != null) {
              employeeLat = coordinates['latitude'] as double;
              employeeLon = coordinates['longitude'] as double;
              debugPrint('[RequestDetailScreen] Géocodage de la localisation pour ${employee.nomComplet}');
            }
          }
        }
        
        if (employeeLat != null && employeeLon != null) {
          // Calculer la distance
          final distance = DistanceCalculator.calculateDistance(
            clientLat,
            clientLon,
            employeeLat,
            employeeLon,
          );
          
          employeesWithDistance.add(MapEntry(employee, distance));
        } else {
          // Si pas de coordonnées disponibles, mettre en fin de liste
          employeesWithDistance.add(MapEntry(employee, double.maxFinite));
        }
      } catch (e) {
        // En cas d'erreur, mettre en fin de liste
        debugPrint('Erreur lors du calcul de distance pour ${employee.nomComplet}: $e');
        employeesWithDistance.add(MapEntry(employee, double.maxFinite));
      }
    }

    // Trier par distance (croissante)
    employeesWithDistance.sort((a, b) => a.value.compareTo(b.value));

    // Stocker les distances pour l'affichage
    for (final entry in employeesWithDistance) {
      final employee = entry.key;
      final distance = entry.value;
      if (distance != double.maxFinite) {
        _employeeDistances[employee.id] = distance;
      }
    }

    // Retourner seulement les employés (sans les distances)
    return employeesWithDistance.map((entry) => entry.key).toList();
  }

  Future<void> _acceptEmployee(String employeeId) async {
    if (_request == null) return;

    final success = await _requestController.acceptEmployeeForRequest(
      _request!.id,
      employeeId,
    );

    if (success) {
      // Create a mission when client accepts an employee
      await _createMission(employeeId);
      await _loadRequest(); // Reload to update UI
    }
  }

  Future<void> _createMission(String employeeId) async {
    try {
      if (_request == null || _authController.currentUser.value == null) return;

      // Get client document ID from user ID
      // First try to get existing client document
      var client = await _clientRepository.getClientByUserId(_request!.clientId);
      
      // If client document doesn't exist, create it
      if (client == null) {
        // Get user data to create client document
        final userRepository = UserRepository();
        final user = await userRepository.getUserById(_request!.clientId);
        
        if (user == null) {
          throw 'Utilisateur non trouvé';
        }
        
        // Create client document
        final clientId = FirebaseFirestore.instance.collection('clients').doc().id;
        final now = DateTime.now();
        
        final newClient = ClientModel(
          id: clientId,
          nomComplet: user.nomComplet,
          localisation: user.localisation,
          tel: user.tel,
          userId: _request!.clientId, // Firebase Auth user ID
          createdAt: now,
          updatedAt: now,
        );
        
        await _clientRepository.createClient(newClient);
        client = newClient;
      }

      final missionId = FirebaseFirestore.instance.collection('missions').doc().id;
      final now = DateTime.now();
      
      // Create mission with default values
      final mission = MissionModel(
        id: missionId,
        prixMission: 0.0, // Will be set later
        dateStart: now,
        dateEnd: now.add(const Duration(days: 1)),
        objMission: _request!.description,
        statutMission: 'Pending',
        employeeId: employeeId,
        clientId: client.id, // Use client document ID
        requestId: _request!.id,
        createdAt: now,
        updatedAt: now,
      );

      await _missionController.createMission(mission);
    } catch (e, stackTrace) {
      Logger.logError('RequestDetailScreen._createMission', e, stackTrace);
      SnackbarHelper.showError( '${'error_creating_mission'.tr}: $e');
    }
  }

  Future<void> _rejectEmployee(String employeeId) async {
    if (_request == null) return;

    final success = await _requestController.rejectEmployeeForRequest(
      _request!.id,
      employeeId,
    );

    if (success) {
      await _loadRequest(); // Reload to update UI
    }
  }

  Future<void> _loadMission(RequestModel request) async {
    try {
      if (request.employeeId == null) return;
      
      // Get client document ID
      final client = await _clientRepository.getClientByUserId(request.clientId);
      if (client == null) return;
      
      // Get all missions for this client and find the one with matching employeeId
      final missions = await _missionRepository.getMissionsByClientId(client.id);
      final mission = missions.firstWhere(
        (m) => m.employeeId == request.employeeId && m.statutMission.toLowerCase() != 'completed',
        orElse: () => missions.firstWhere(
          (m) => m.employeeId == request.employeeId,
          orElse: () => missions.isNotEmpty ? missions.first : throw StateError('No mission found'),
        ),
      );
      
      setState(() {
        _mission = mission;
      });
    } catch (e) {
      // Mission might not exist yet or not found
      setState(() {
        _mission = null;
      });
    }
  }

  Future<void> _loadAssignedEmployee(String employeeId) async {
    try {
      final employee = await _employeeController.getEmployeeById(employeeId);
      if (mounted) {
        setState(() {
          _assignedEmployee = employee;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _assignedEmployee = null;
        });
      }
    }
  }

  Future<void> _finishRequest() async {
    if (_request == null || _mission == null) return;
    
    // Show dialog for price feedback
    final result = await _showFinishDialog();
    if (result == null) return;
    
    final price = result['price'] as double;
    final rating = result['rating'] as double?;
    final comment = result['comment'] as String?;
    
    try {
      // Generate QR code token
      final token = await _qrCodeService.createFinishToken(
        requestId: _request!.id,
        clientId: _request!.clientId,
        employeeId: _request!.employeeId!,
        price: price,
        rating: rating,
        comment: comment,
      );
      
      // Show QR code dialog
      await _showQRCodeDialog(token);
    } catch (e, stackTrace) {
      Logger.logError('RequestDetailScreen._finishRequest', e, stackTrace);
      SnackbarHelper.showError('${'error_finishing'.tr}: $e');
    }
  }
  
  Future<void> _showQRCodeDialog(String token) async {
    final completer = Completer<void>();
    StreamSubscription<DocumentSnapshot>? subscription;
    bool dialogClosed = false;

    // Listen to token changes
    subscription = FirebaseFirestore.instance
        .collection('request_finish_tokens')
        .doc(token)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['used'] == true && !dialogClosed) {
          dialogClosed = true;
          subscription?.cancel();
          Get.back(); // Close the dialog
          completer.complete();
          // Reload request data
          _loadRequest();
          SnackbarHelper.showSuccess('request_completed_success'.tr);
        }
      }
    });

    await Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'qr_code_title'.tr,
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'qr_code_description'.tr,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1),
                ),
                child: QrImageView(
                  data: token,
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                onPressed: () {
                  dialogClosed = true;
                  subscription?.cancel();
                  Get.back();
                  completer.complete();
                },
                text: 'close'.tr,
                backgroundColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    // Cancel subscription if dialog is closed manually
    if (!dialogClosed) {
      subscription.cancel();
    }
  }

  Future<Map<String, dynamic>?> _showFinishDialog() async {
    final priceController = TextEditingController(text: _mission?.prixMission.toStringAsFixed(2) ?? '0.00');
    final commentController = TextEditingController();
    final selectedRating = ValueNotifier<double?>(null);
    
    return await Get.dialog<Map<String, dynamic>>(
      Dialog(
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildRatingStars() {
              return ValueListenableBuilder<double?>(
                valueListenable: selectedRating,
                builder: (context, rating, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starRating = (index + 1).toDouble();
                      final isSelected = rating != null && starRating <= rating;
                      return IconButton(
                        icon: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          color: isSelected ? AppColors.warning : AppColors.grey,
                        ),
                        onPressed: () {
                          selectedRating.value = selectedRating.value == starRating ? null : starRating;
                        },
                      );
                    }),
                  );
                },
              );
            }
            
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'finish_dialog_title'.tr,
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 24),
                  
                  // Price input
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '${'price'.tr} (€)',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Rating
                  Text(
                    '${'rating'.tr} (${'optional'.tr})',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  buildRatingStars(),
                  const SizedBox(height: 16),
                  
                  // Comment
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'comment_hint'.tr,
                      hintText: 'comment_hint'.tr,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('cancel'.tr),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          onPressed: () {
                            final price = double.tryParse(priceController.text);
                            if (price == null || price < 0) {
                              SnackbarHelper.showError( 'enter_valid_price'.tr);
                              return;
                            }
                            Get.back(result: {
                              'price': price,
                              'rating': selectedRating.value,
                              'comment': commentController.text.trim().isEmpty 
                                  ? null 
                                  : commentController.text.trim(),
                            });
                          },
                          text: 'finish'.tr,
                          backgroundColor: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool get _isCurrentUserAssignedEmployee {
    final user = _authController.currentUser.value;
    if (user == null || _request == null || _request!.employeeId == null) return false;
    
    // Check if user is an employee
    if (user.type.toLowerCase() != 'employee') return false;
    
    // Check if current user is the assigned employee
    // First try using _assignedEmployee if available
    if (_assignedEmployee != null) {
      return _assignedEmployee!.userId == user.id;
    }
    
    // Fallback: try to match using employeeId from request
    // Note: employeeId in request is document ID, we need to check if current user's employee document matches
    // For now, we'll show the button if user is an employee and request has an employeeId
    // This is a simplified check - ideally we'd fetch the employee document and compare
    return true; // Show for any employee viewing an accepted request
  }
  
  bool get _shouldShowQRButton {
    final user = _authController.currentUser.value;
    if (user == null || _request == null) return false;
    
    // Only show for employees
    if (user.type.toLowerCase() != 'employee') return false;
    
    // Only show if request is accepted and has an employee assigned
    if (_request!.statut.toLowerCase() != 'accepted' || _request!.employeeId == null) return false;
    
    // Only show if mission exists and is not completed
    if (_mission == null || _mission!.statutMission.toLowerCase() == 'completed') return false;
    
    return true;
  }

  bool get _canCurrentUserChat {
    if (_request == null || _request!.employeeId == null) return false;
    if (_request!.statut.toLowerCase() != 'accepted') return false;
    final user = _authController.currentUser.value;
    if (user == null) return false;
    final isClient = user.id == _request!.clientId;
    return isClient || _isCurrentUserAssignedEmployee;
  }

  void _openChat() {
    if (_request == null || _request!.employeeId == null) return;
    final request = _request!;
    final args = ChatScreenArguments(
      requestId: request.id,
      clientId: request.clientId,
      employeeId: request.employeeId!,
      requestTitle: '${'request'.tr} #${request.id.substring(0, 8)}',
      requestStatus: request.statut,
      clientName: _authController.currentUser.value?.id == request.clientId
          ? _authController.currentUser.value?.nomComplet
          : null,
      employeeName: _assignedEmployee?.nomComplet,
      employeeUserId: _assignedEmployee?.userId,
    );

    Get.toNamed(AppRoutes.AppRoutes.chat, arguments: args);
  }

  void _openQRScanner() async {
    final result = await Get.toNamed(AppRoutes.AppRoutes.qrScanner);
    if (result == true) {
      // Reload data if QR code was successfully scanned
      await _loadRequest();
      SnackbarHelper.showSuccess('request_completed_success'.tr);
      Get.back(result: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authController.currentUser.value;
    final isClient = user != null && user.type.toLowerCase() == 'client';
    final assignedEmployee = _assignedEmployee;
    final canChat = _canCurrentUserChat;

    return Scaffold(
      appBar: AppBar(
        title: Text('request_details'.tr),
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingWidget()
            : _request == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'request_not_found'.tr,
                          style: AppTextStyles.h3,
                        ),
                      ],
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final bottomPadding = MediaQuery.of(context).padding.bottom;
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Request Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${'request'.tr} #${_request!.id.substring(0, 8)}',
                                      style: AppTextStyles.h3,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(_request!.statut),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getStatusText(_request!.statut),
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'description'.tr,
                                style: AppTextStyles.h4.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _request!.description,
                                style: AppTextStyles.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _request!.address,
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Accepted Employees Section (for clients)
                      if (isClient && _request!.statut.toLowerCase() == 'pending')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'accepted_employees'.tr,
                              style: AppTextStyles.h3,
                            ),
                            const SizedBox(height: 16),
                            if (_acceptedEmployees.isEmpty)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 48,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'no_employee_accepted'.tr,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ..._acceptedEmployees.map((employee) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 30,
                                              backgroundColor: AppColors.primaryLight,
                                              backgroundImage: employee.image != null
                                                  ? NetworkImage(employee.image!)
                                                  : null,
                                              child: employee.image == null
                                                  ? Text(
                                                      employee.nomComplet[0].toUpperCase(),
                                                      style: const TextStyle(
                                                        color: AppColors.primary,
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    employee.nomComplet,
                                                    style: AppTextStyles.h4,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    employee.competence,
                                                    style: AppTextStyles.bodySmall.copyWith(
                                                      color: AppColors.textSecondary,
                                                    ),
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
                                                      Text(
                                                        employee.ville,
                                                        style: AppTextStyles.bodySmall.copyWith(
                                                          color: AppColors.textSecondary,
                                                        ),
                                                      ),
                                                      if (_employeeDistances.containsKey(employee.id)) ...[
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.primary.withOpacity(0.2),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(
                                                                Icons.navigation,
                                                                size: 12,
                                                                color: AppColors.primary,
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                DistanceCalculator.formatDistance(_employeeDistances[employee.id]!),
                                                                style: AppTextStyles.bodySmall.copyWith(
                                                                  color: AppColors.primary,
                                                                  fontWeight: FontWeight.w600,
                                                                  fontSize: 11,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (employee.bio != null && employee.bio!.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            employee.bio!,
                                            style: AppTextStyles.bodySmall,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        // Employee Statistics (Brief)
                                        if (_employeeStatistics.containsKey(employee.id)) ...[
                                          const SizedBox(height: 12),
                                          EmployeeStatisticsWidget(
                                            statistics: _employeeStatistics[employee.id]!,
                                            isCompact: true,
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => _rejectEmployee(employee.id),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppColors.error,
                                                  side: const BorderSide(color: AppColors.error),
                                                ),
                                                child: Text('refuse'.tr),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Obx(
                                                () => CustomButton(
                                                  onPressed: _requestController.isLoading.value
                                                      ? null
                                                      : () => _acceptEmployee(employee.id),
                                                  text: 'accept'.tr,
                                                  isLoading: _requestController.isLoading.value,
                                                  backgroundColor: AppColors.success,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),

                      // Show accepted employee info if request is accepted
                      if (assignedEmployee != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'assigned_employee'.tr,
                                  style: AppTextStyles.h3,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: AppColors.primaryLight,
                                      backgroundImage: assignedEmployee.image != null
                                          ? NetworkImage(assignedEmployee.image!)
                                          : null,
                                      child: assignedEmployee.image == null
                                          ? Text(
                                              assignedEmployee.nomComplet[0].toUpperCase(),
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            assignedEmployee.nomComplet,
                                            style: AppTextStyles.h4,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            assignedEmployee.competence,
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (isClient &&
                                    _mission != null &&
                                    _mission!.statutMission.toLowerCase() != 'completed')
                                  Obx(
                                    () => CustomButton(
                                      onPressed: _missionController.isLoading.value
                                          ? null
                                          : _finishRequest,
                                      text: 'finish_request'.tr,
                                      backgroundColor: AppColors.success,
                                      isLoading: _missionController.isLoading.value,
                                    ),
                                  ),
                                if (canChat) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CustomButton(
                                          onPressed: _openChat,
                                          text: 'open_chat'.tr,
                                          backgroundColor: AppColors.info,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Audio Call Button
                                      CallButton(
                                        calleeId: _getRemoteUserId(),
                                        video: false,
                                        iconColor: AppColors.success,
                                      ),
                                      // Video Call Button
                                      CallButton(
                                        calleeId: _getRemoteUserId(),
                                        video: true,
                                        iconColor: AppColors.primary,
                                      ),
                                      // QR Scanner button for employee
                                      if (_shouldShowQRButton) ...[
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 50,
                                          height: 50,
                                          child: ElevatedButton(
                                            onPressed: _openQRScanner,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.warning,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                              padding: EdgeInsets.zero,
                                            ),
                                            child: Icon(
                                              Icons.qr_code_scanner,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                                // QR Scanner button for employee (shown even if canChat is false)
                                if (!canChat && _shouldShowQRButton) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
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
                                ],
                              ],
                            ),
                          ),
                        ),

                      // Mission Card - Show mission info and QR scanner button for employee
                      if (_mission != null)
                        Card(
                          margin: const EdgeInsets.only(top: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'mission'.tr,
                                  style: AppTextStyles.h3,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${'mission_price'.tr}: ${_mission!.prixMission.toStringAsFixed(2)} €',
                                            style: AppTextStyles.bodyMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${'mission_status'.tr}: ${_mission!.statutMission}',
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // QR Scanner button for employee
                                if (_shouldShowQRButton) ...[
                                  const SizedBox(height: 16),
                                  if (canChat)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: CustomButton(
                                            onPressed: _openChat,
                                            text: 'open_chat'.tr,
                                            backgroundColor: AppColors.info,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Audio Call Button
                                        CallButton(
                                          calleeId: _getRemoteUserId(),
                                          video: false,
                                          iconColor: AppColors.success,
                                        ),
                                        // Video Call Button
                                        CallButton(
                                          calleeId: _getRemoteUserId(),
                                          video: true,
                                          iconColor: AppColors.primary,
                                        ),
                                        // QR Scanner button
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 50,
                                          height: 50,
                                          child: ElevatedButton(
                                            onPressed: _openQRScanner,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.warning,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: 2,
                                              padding: EdgeInsets.zero,
                                            ),
                                            child: Icon(
                                              Icons.qr_code_scanner,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    SizedBox(
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
                                ],
                              ],
                            ),
                          ),
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

  String _getRemoteUserId() {
    if (_request == null || _request!.employeeId == null) return '';
    final user = _authController.currentUser.value;
    if (user == null) return '';

    return user.id == _request!.clientId
        ? (_assignedEmployee?.userId ?? _request!.employeeId ?? '')
        : _request!.clientId;
  }
}

