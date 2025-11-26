import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../../controllers/auth_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../controllers/request_controller.dart';
import '../../controllers/request_flow_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../controllers/categorie_controller.dart';
import '../../data/models/request_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/location_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/employee_statistics_service.dart';
import '../../core/services/realtime_request_service.dart';
import '../../data/models/employee_statistics.dart';
import '../../data/models/mission_model.dart';
import '../../data/models/client_model.dart';
import '../../data/models/accepted_employee_summary.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import '../../components/indrive_app_bar.dart';
import '../../components/indrive_button.dart';
import '../../components/indrive_dialog_template.dart';
import '../../components/app_sidebar.dart';
import '../../components/language_switcher.dart';
import '../../components/user_location_map.dart';
import '../../components/draggable_request_form.dart';
import '../../core/helpers/snackbar_helper.dart';
import '../../core/enums/request_flow_state.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/cancellation_report_dialog.dart';
import '../../data/repositories/cancellation_report_repository.dart';
import '../../data/models/cancellation_report_model.dart';
import '../../data/repositories/employee_repository.dart';
import '../../data/repositories/mission_repository.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/qr_code_service.dart';
import '../../core/utils/logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'chat_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Dashboard Client
class ClientDashboardScreen extends StatelessWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ClientHomeScreen();
  }
}

/// Home screen content for Client - Refonte complète avec design InDrive
class _ClientHomeScreen extends StatefulWidget {
  const _ClientHomeScreen();

  @override
  State<_ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<_ClientHomeScreen> with WidgetsBindingObserver {
  final AuthController _authController = Get.find<AuthController>();
  final MissionController _missionController = Get.put(MissionController());
  final RequestController _requestController = Get.put(RequestController());
  final CategorieController _categorieController = Get.put(CategorieController());
  final EmployeeController _employeeController = Get.put(EmployeeController());
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();
  final EmployeeStatisticsService _statisticsService = EmployeeStatisticsService();
  final RequestRepository _requestRepository = RequestRepository();
  RealtimeRequestService? _realtimeService;
  StreamSubscription<RequestModel?>? _requestStreamSubscription;
  StreamSubscription<List<EmployeeModel>>? _employeesStreamSubscription;
  StreamSubscription<bool>? _connectionStatusSubscription;
  
  RequestFlowController get _requestFlowController {
    try {
      return Get.find<RequestFlowController>();
    } catch (_) {
      return Get.put(RequestFlowController());
    }
  }
  
  final ClientRepository _clientRepository = ClientRepository();
  final CancellationReportRepository _cancellationReportRepository = CancellationReportRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final MissionRepository _missionRepository = MissionRepository();
  final LocalNotificationService _notificationService = LocalNotificationService();
  final QRCodeService _qrCodeService = QRCodeService();
  String? _loadedUserId;

  // Formulaire de demande - Utiliser ValueNotifier pour éviter les setState()
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final ValueNotifier<String?> _selectedCategorieIdNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _currentAddressNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<double?> _latitudeNotifier = ValueNotifier<double?>(null);
  final ValueNotifier<double?> _longitudeNotifier = ValueNotifier<double?>(null);
  final ValueNotifier<bool> _isLoadingLocationNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isSubmittingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<File>> _selectedImagesNotifier = ValueNotifier<List<File>>([]);

  // Employés acceptés (gérés par stream temps réel)
  final ValueNotifier<List<EmployeeModel>> _acceptedEmployeesNotifier = ValueNotifier<List<EmployeeModel>>([]);
  final Map<String, EmployeeStatistics> _employeeStatistics = {};
  final ValueNotifier<bool> _isLoadingEmployees = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isConnected = ValueNotifier<bool>(true);
  
  // Employé sélectionné (si demande acceptée) - Utiliser ValueNotifier
  final ValueNotifier<EmployeeModel?> _selectedEmployeeNotifier = ValueNotifier<EmployeeModel?>(null);
  
  // RequestModel actif pour les animations
  RequestModel? _currentRequestForAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _autoFetchLocation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _descriptionController.dispose();
    _requestStreamSubscription?.cancel();
    _employeesStreamSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _realtimeService?.dispose();
    _realtimeService = null;
    _acceptedEmployeesNotifier.dispose();
    _isLoadingEmployees.dispose();
    _isConnected.dispose();
    _selectedCategorieIdNotifier.dispose();
    _currentAddressNotifier.dispose();
    _latitudeNotifier.dispose();
    _longitudeNotifier.dispose();
    _isLoadingLocationNotifier.dispose();
    _isSubmittingNotifier.dispose();
    _selectedImagesNotifier.dispose();
    _selectedEmployeeNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Le stream temps réel se reconnecte automatiquement
    // Pas besoin de refresh manuel
  }

  void _loadData({bool forceRefresh = false}) {
    final user = _authController.currentUser.value;
    if (user != null) {
      if (forceRefresh || _loadedUserId != user.id) {
        _loadClientAndRefresh(user.id);
        _requestController.streamRequestsByClient(user.id);
        _categorieController.loadAllCategories();
        _loadedUserId = user.id;
      }
    }
  }

  Future<void> _loadClientAndRefresh(String userId) async {
    try {
      final client = await _clientRepository.getClientByUserId(userId);
      if (client != null) {
        await _missionController.streamMissionsByClient(client.id);
      } else {
        _missionController.missions.clear();
      }
    } catch (e) {
      _missionController.missions.clear();
    }
  }

  Future<void> _autoFetchLocation() async {
    try {
      final locationData = await _locationService.getCurrentLocationWithAddress();
      if (mounted) {
        _latitudeNotifier.value = locationData['latitude'] as double;
        _longitudeNotifier.value = locationData['longitude'] as double;
        _currentAddressNotifier.value = locationData['address'] as String;
      }
    } catch (e) {
      // Silently fail - location will be requested when submitting
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!mounted) return;
      _isLoadingLocationNotifier.value = true;

      final locationData = await _locationService.getCurrentLocationWithAddress();

      if (mounted) {
        _latitudeNotifier.value = locationData['latitude'] as double;
        _longitudeNotifier.value = locationData['longitude'] as double;
        _currentAddressNotifier.value = locationData['address'] as String;
        _isLoadingLocationNotifier.value = false;
        SnackbarHelper.showSuccess('location_retrieved'.tr);
      }
    } catch (e) {
      if (mounted) {
        _isLoadingLocationNotifier.value = false;
        SnackbarHelper.showError(e.toString());
      }
    }
  }

  /// Initialiser le stream temps réel pour les employés acceptés
  void _initRealtimeEmployeesStream(String requestId) {
    if (!mounted) return;
    
    // Arrêter l'ancien service s'il existe
    _employeesStreamSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _realtimeService?.stop();
    
    // Créer une nouvelle instance du service pour éviter les problèmes de lifecycle
    _realtimeService = RealtimeRequestService();

    // Écouter le statut de connexion
    _connectionStatusSubscription = _realtimeService!.connectionStatusStream.listen(
      (connected) {
        if (mounted) {
          _isConnected.value = connected;
          if (!connected) {
            SnackbarHelper.showInfo('connection_lost'.tr);
          } else {
            SnackbarHelper.showSuccess('connection_restored'.tr);
          }
        }
      },
    );

    // Écouter les employés acceptés en temps réel
    try {
      _realtimeService!.listenToAcceptedEmployeesDirect(requestId);
    } catch (e) {
      debugPrint('Error initializing employees stream: $e');
      if (mounted) {
        _isLoadingEmployees.value = false;
      }
      return;
    }
    
    _employeesStreamSubscription = _realtimeService!.employeesStream.listen(
      (employees) async {
        if (!mounted) return;

        // Mettre à jour la liste immédiatement pour un feedback visuel rapide
        _acceptedEmployeesNotifier.value = employees;
        _isLoadingEmployees.value = false;

        // Charger les statistiques en arrière-plan (de manière asynchrone et non-bloquante)
        // Utiliser un microtask pour éviter de bloquer le thread principal
        scheduleMicrotask(() async {
          if (!mounted) return;
          
          final statsToLoad = <String>[];
          for (final employee in employees) {
            if (!_employeeStatistics.containsKey(employee.id)) {
              statsToLoad.add(employee.id);
            }
          }

          // Charger les statistiques en parallèle pour améliorer les performances
          if (statsToLoad.isNotEmpty) {
            final futures = statsToLoad.map((id) async {
              try {
                final stats = await _statisticsService.getEmployeeStatisticsByStringId(id);
                if (mounted) {
                  _employeeStatistics[id] = stats;
                }
              } catch (e) {
                debugPrint('Error loading stats for employee $id: $e');
              }
            });
            
            await Future.wait(futures);
            
            // Forcer un rebuild pour afficher les statistiques chargées
            if (mounted) {
              _acceptedEmployeesNotifier.value = List.from(_acceptedEmployeesNotifier.value);
            }
          }
        });
      },
      onError: (error) {
        if (mounted) {
          _isLoadingEmployees.value = false;
          debugPrint('Error in employees stream: $error');
        }
      },
    );

    _isLoadingEmployees.value = true;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategorieIdNotifier.value == null) {
      SnackbarHelper.showError('category_required'.tr);
      return;
    }

    if (_latitudeNotifier.value == null || _longitudeNotifier.value == null || _currentAddressNotifier.value == null) {
      SnackbarHelper.showError('location_required'.tr);
      return;
    }

    if (_authController.currentUser.value == null) {
      SnackbarHelper.showError('must_be_connected'.tr);
      return;
    }

    // Vérifier si le client a déjà une demande active
    final hasActive = await _requestController.hasActiveRequest(
      _authController.currentUser.value!.id,
    );

    if (hasActive) {
      final activeRequest = await _requestController.getActiveRequest(
        _authController.currentUser.value!.id,
      );
      final statusText = activeRequest?.statut.toLowerCase() == 'pending' 
          ? 'status_pending'.tr 
          : 'status_accepted'.tr;
      
      SnackbarHelper.showSnackbar(
        title: 'request_in_progress'.tr,
        message: 'request_in_progress_message'.tr.replaceAll('{status}', statusText),
        duration: const Duration(seconds: 4),
        backgroundColor: AppColors.warning.withOpacity(0.9),
        colorText: AppColors.white,
      );
      return;
    }

    _isSubmittingNotifier.value = true;

    try {
      final requestId = FirebaseFirestore.instance.collection('requests').doc().id;

      // Uploader les images si disponibles
      List<String> imageUrls = [];
      if (_selectedImagesNotifier.value.isNotEmpty) {
        for (int i = 0; i < _selectedImagesNotifier.value.length; i++) {
          final imageUrl = await _storageService.uploadRequestImage(
            requestId: requestId,
            imageFile: _selectedImagesNotifier.value[i],
            index: i,
          );
          imageUrls.add(imageUrl);
        }
      }

      // Créer la demande
      final request = RequestModel(
        id: requestId,
        description: _descriptionController.text.trim(),
        images: imageUrls.isEmpty ? null : imageUrls,
        latitude: _latitudeNotifier.value!,
        longitude: _longitudeNotifier.value!,
        address: _currentAddressNotifier.value!,
        categorieId: _selectedCategorieIdNotifier.value!,
        clientId: _authController.currentUser.value!.id,
        statut: 'Pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Sauvegarder la demande
      final success = await _requestController.createRequest(request);

      if (success) {
        // Démarrer le flux de demande
        await _requestFlowController.startPendingFlow(request);
        
        if (mounted) {
          // Réinitialiser le formulaire
          _descriptionController.clear();
          _selectedCategorieIdNotifier.value = null;
          _selectedImagesNotifier.value = [];
          
        // Le stream temps réel sera initialisé automatiquement dans build()
          
          SnackbarHelper.showSuccess('request_submitted_success'.tr);
        }
      }
    } catch (e) {
      SnackbarHelper.showError('${'error_submitting'.tr}: $e');
    } finally {
      if (mounted) {
        _isSubmittingNotifier.value = false;
      }
    }
  }

  Future<void> _acceptEmployee(String employeeId) async {
    final activeRequest = _requestFlowController.activeRequest.value;
    if (activeRequest == null) return;

    if (!mounted) return;
    _isSubmittingNotifier.value = true;

    try {
      final success = await _requestController.acceptEmployeeForRequest(
        activeRequest.id,
        employeeId,
      );

      if (success && mounted) {
        // Créer la mission
        await _createMission(employeeId, activeRequest);
        
        // Charger l'employé sélectionné
        await _loadSelectedEmployee(employeeId);
        
        // Mettre à jour le RequestFlowController
        final selectedEmployee = _selectedEmployeeNotifier.value;
        await _requestFlowController.markAccepted(
          AcceptedEmployeeSummary(
            id: employeeId,
            name: selectedEmployee?.nomComplet,
            service: selectedEmployee?.competence,
            city: selectedEmployee?.ville,
            rating: _employeeStatistics[employeeId]?.averageRating,
            photoUrl: selectedEmployee?.image,
          ),
        );
        
        SnackbarHelper.showSuccess('employee_accepted'.tr);
        // Le stream temps réel mettra à jour automatiquement
      } else if (!success) {
        SnackbarHelper.showError('error_accepting_employee'.tr);
      }
    } catch (e) {
      SnackbarHelper.showError('${'error_accepting_employee'.tr}: $e');
    } finally {
      if (mounted) {
        _isSubmittingNotifier.value = false;
      }
    }
  }

  Future<void> _createMission(String employeeId, RequestModel request) async {
    try {
      if (_authController.currentUser.value == null) return;

      // Get client document ID from user ID
      var client = await _clientRepository.getClientByUserId(request.clientId);
      
      // If client document doesn't exist, create it
      if (client == null) {
        final userRepository = UserRepository();
        final user = await userRepository.getUserById(request.clientId);
        
        if (user == null) {
          throw 'Utilisateur non trouvé';
        }
        
        final clientId = FirebaseFirestore.instance.collection('clients').doc().id;
        final now = DateTime.now();
        
        final newClient = ClientModel(
          id: clientId,
          nomComplet: user.nomComplet,
          localisation: user.localisation,
          tel: user.tel,
          userId: request.clientId,
          createdAt: now,
          updatedAt: now,
        );
        
        await _clientRepository.createClient(newClient);
        client = newClient;
      }

      final missionId = FirebaseFirestore.instance.collection('missions').doc().id;
      final now = DateTime.now();
      
      final mission = MissionModel(
        id: missionId,
        prixMission: 0.0,
        dateStart: now,
        dateEnd: now.add(const Duration(days: 1)),
        objMission: request.description,
        statutMission: 'Pending',
        employeeId: employeeId,
        clientId: client.id,
          requestId: request.id,
        createdAt: now,
        updatedAt: now,
      );

      await _missionController.createMission(mission);
    } catch (e) {
      // Log error but don't block the flow
      debugPrint('Error creating mission: $e');
    }
  }

  Future<void> _loadSelectedEmployee(String employeeId) async {
    try {
      final employee = await _employeeController.getEmployeeById(employeeId);
      if (employee != null && mounted) {
        _selectedEmployeeNotifier.value = employee;
        // Charger les statistiques
        if (!_employeeStatistics.containsKey(employeeId)) {
          final stats = await _statisticsService.getEmployeeStatisticsByStringId(employeeId);
          if (mounted) {
            _employeeStatistics[employeeId] = stats;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading selected employee: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty && mounted) {
        _selectedImagesNotifier.value = images.map((image) => File(image.path)).toList();
      }
    } catch (e) {
      SnackbarHelper.showError('${'error_selecting_images'.tr}: $e');
    }
  }

  String? _lastActiveRequestId;
  RequestFlowState? _lastFlowState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppSidebar(),
      appBar: InDriveAppBar(
        title: 'client_dashboard'.tr,
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
      backgroundColor: AppColors.night,
      body: Obx(
        () {
          final user = _authController.currentUser.value;

          if (user == null) {
            return const LoadingWidget();
          }

          if (_loadedUserId != user.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _loadData();
              }
            });
          }

          final flowState = _requestFlowController.currentState.value;
          final activeRequest = _requestFlowController.activeRequest.value;

          // Initialiser les streams UNIQUEMENT si l'état a changé (évite les rebuilds inutiles)
          final currentRequestId = activeRequest?.id;
          if (currentRequestId != _lastActiveRequestId || flowState != _lastFlowState) {
            _lastActiveRequestId = currentRequestId;
            _lastFlowState = flowState;
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              
              // Écouter les changements de la demande en temps réel
              if (activeRequest != null && (flowState == RequestFlowState.pending || flowState == RequestFlowState.accepted)) {
                // Stream de la demande pour les mises à jour d'état
                _requestStreamSubscription?.cancel();
                _requestStreamSubscription = _requestRepository.streamRequest(activeRequest.id).listen((request) {
                  if (request != null && mounted) {
                    // Si un employé est sélectionné, le charger
                    if (request.employeeId != null && _selectedEmployeeNotifier.value == null) {
                      _loadSelectedEmployee(request.employeeId!);
                    }
                    // Mettre à jour le RequestFlowController si l'état change
                    if (request.statut.toLowerCase() == 'accepted' && flowState == RequestFlowState.pending) {
                      _requestFlowController.markAccepted(
                        AcceptedEmployeeSummary(
                          id: request.employeeId ?? '',
                          name: _selectedEmployeeNotifier.value?.nomComplet,
                          service: _selectedEmployeeNotifier.value?.competence,
                          city: _selectedEmployeeNotifier.value?.ville,
                          rating: _employeeStatistics[request.employeeId ?? '']?.averageRating,
                          photoUrl: _selectedEmployeeNotifier.value?.image,
                        ),
                      );
                    }
                  }
                });
                
                // Initialiser le stream temps réel pour les employés acceptés
                if (flowState == RequestFlowState.pending) {
                  _currentRequestForAnimation = activeRequest;
                  _initRealtimeEmployeesStream(activeRequest.id);
                }
                
                // Charger l'employé sélectionné si nécessaire
                if (flowState == RequestFlowState.accepted && activeRequest.employeeId != null && _selectedEmployeeNotifier.value == null) {
                  _loadSelectedEmployee(activeRequest.employeeId!);
                }
              } else {
                // Arrêter les streams si pas de demande active (sans fermer les controllers)
                _employeesStreamSubscription?.cancel();
                _connectionStatusSubscription?.cancel();
                _realtimeService?.stop();
                if (mounted) {
                  _acceptedEmployeesNotifier.value = [];
                  _currentRequestForAnimation = null;
                }
              }
            });
          }

          // Si pas de demande active, afficher le formulaire glissant
          if (flowState == RequestFlowState.idle) {
            return Stack(
              children: [
                // Contenu principal
                _buildUnifiedView(user, flowState, activeRequest),
                // Formulaire glissant en bas - doit être directement dans Stack, pas Positioned
                DraggableRequestForm(
                  formKey: _formKey,
                  descriptionController: _descriptionController,
                  selectedCategorieIdNotifier: _selectedCategorieIdNotifier,
                  selectedImagesNotifier: _selectedImagesNotifier,
                  onPickImages: _pickImages,
                  onSubmit: _submitRequest,
                  isSubmittingNotifier: _isSubmittingNotifier,
                  categories: _categorieController.categories,
                  isLoadingCategories: _categorieController.isLoading.value,
                ),
              ],
            );
          } else {
            // Si demande active, afficher seulement le contenu principal
            return _buildUnifiedView(user, flowState, activeRequest);
          }
        },
      ),
    );
  }

  /// Vue unifiée avec affichage conditionnel selon l'état
  Widget _buildUnifiedView(user, RequestFlowState flowState, RequestModel? activeRequest) {
    // Ajouter un padding en bas si le formulaire est visible pour éviter qu'il cache le contenu
    // Prendre en compte les safe areas (boutons de navigation système)
    final mediaQuery = MediaQuery.of(context);
    final systemBottomPadding = mediaQuery.padding.bottom;
    final baseBottomPadding = flowState == RequestFlowState.idle ? 400.0 : 32.0;
    final bottomPadding = baseBottomPadding + systemBottomPadding;
    
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
          // Section A : Header client OU Liste employés avec transition fluide
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              );
            },
            child: flowState == RequestFlowState.idle
                ? _buildUserHeader(user)
                : flowState == RequestFlowState.pending && activeRequest != null
                    ? _buildAcceptedEmployeesList(activeRequest)
                    : flowState == RequestFlowState.accepted && activeRequest != null
                        ? ValueListenableBuilder<EmployeeModel?>(
                            valueListenable: _selectedEmployeeNotifier,
                            builder: (context, selectedEmployee, _) {
                              return selectedEmployee != null
                                  ? _buildSelectedEmployeeHeader(selectedEmployee)
                                  : const LoadingWidget();
                            },
                          )
                        : _buildUserHeader(user),
          ),
          
          const SizedBox(height: 24),

          // Section B : Infos demande (si active) OU rien (le formulaire est dans le bottom sheet)
          if (flowState != RequestFlowState.idle && activeRequest != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    )),
                    child: child,
                  ),
                );
              },
              child: _buildRequestDetailsCard(activeRequest, flowState),
            ),
          
          const SizedBox(height: 24),

          // Section C : Boutons d'action selon l'état
          if (flowState == RequestFlowState.pending && activeRequest != null)
            _buildCancelRequestButton(activeRequest)
          else if (flowState == RequestFlowState.accepted && activeRequest != null)
            _buildAcceptedRequestActions(activeRequest),
        ],
      ),
    );
  }

  /// Header avec infos client + localisation - Design moderne amélioré
  Widget _buildUserHeader(user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Infos client avec design moderne et gradient (thème sombre)
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AppColors.nightSurface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Photo de profil avec gradient et ombre
                    Container(
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
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.white,
                        child: Text(
                          user.nomComplet.substring(0, 1).toUpperCase(),
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    // Infos utilisateur
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                            user.nomComplet,
                            style: AppTextStyles.h3.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.public,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  user.localisation.isNotEmpty ? user.localisation : 'Localisation non définie',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Adresse actuelle avec design amélioré (thème sombre)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.nightSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white10,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 20,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ValueListenableBuilder<String?>(
                          valueListenable: _currentAddressNotifier,
                          builder: (context, address, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                  'Votre position',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  address ?? 'Localisation non disponible',
                              style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _isLoadingLocationNotifier,
                        builder: (context, isLoading, _) {
                          if (isLoading) {
                            return const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            );
                          }
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _getCurrentLocation,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Carte de localisation en temps réel - Position sous les infos client (thème sombre)
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: UserLocationMap(
              height: 280,
              borderRadius: 24,
              onLocationChanged: (latLng) {
                // Mettre à jour les coordonnées sans rebuild complet
                if (mounted) {
                  _latitudeNotifier.value = latLng.latitude;
                  _longitudeNotifier.value = latLng.longitude;
                  
                  // Mettre à jour l'adresse en arrière-plan
                  _updateAddressFromCoordinates(latLng.latitude, latLng.longitude);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Mettre à jour l'adresse à partir des coordonnées (en arrière-plan)
  Future<void> _updateAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final address = await _locationService.getAddressFromCoordinates(
        latitude: latitude,
        longitude: longitude,
      );
      if (mounted) {
        _currentAddressNotifier.value = address;
      }
    } catch (e) {
      // Ignorer silencieusement les erreurs de géocodification
      debugPrint('Erreur lors de la mise à jour de l\'adresse: $e');
    }
  }

  // Les méthodes _buildCategorySelector, _buildDescriptionForm, et _buildSubmitButton
  // ont été déplacées dans le widget DraggableRequestForm et ne sont plus utilisées ici

  /// Liste des employés acceptés (remplace le header client) avec animations temps réel
  Widget _buildAcceptedEmployeesList(RequestModel request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header avec indicateur de connexion
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'accepted_employees'.tr,
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'select_employee_message'.tr,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            // Indicateur de connexion discret
            ValueListenableBuilder<bool>(
              valueListenable: _isConnected,
              builder: (context, connected, _) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? AppColors.success : AppColors.error,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Liste animée des employés
        ValueListenableBuilder<bool>(
          valueListenable: _isLoadingEmployees,
          builder: (context, isLoading, _) {
            if (isLoading) {
              return const LoadingWidget();
            }
            return ValueListenableBuilder<List<EmployeeModel>>(
              valueListenable: _acceptedEmployeesNotifier,
              builder: (context, employees, _) {
                if (employees.isEmpty) {
                      return EmptyState(
                    icon: Icons.person_outline,
                    title: 'no_employee_accepted'.tr,
                    message: 'waiting_employees'.tr,
                  );
                }
                
                // Utiliser une liste avec animations pour les mises à jour fluides
                if (_currentRequestForAnimation == null) {
                  _currentRequestForAnimation = request;
                }
                
                // Utiliser ListView.builder avec transitions pour les animations
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                  itemCount: employees.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                    final employee = employees[index];
                    final stats = _employeeStatistics[employee.id] ?? EmployeeStatistics.empty();
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.3),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          )),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: _buildEmployeeCard(
                        employee,
                        stats,
                        _currentRequestForAnimation!,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }


  /// Header de l'employé sélectionné (remplace le header client)
  Widget _buildSelectedEmployeeHeader(EmployeeModel employee) {
    final stats = _employeeStatistics[employee.id] ?? EmployeeStatistics.empty();

                        return Container(
      decoration: BoxDecoration(
        color: AppColors.nightSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.secondary.withOpacity(0.15),
                backgroundImage: employee.image != null
                    ? NetworkImage(employee.image!)
                    : null,
                child: employee.image == null
                    ? Text(
                        employee.nomComplet.substring(0, 1).toUpperCase(),
                        style: AppTextStyles.h3.copyWith(color: AppColors.secondary),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.nomComplet,
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (employee.competence.isNotEmpty)
                      Text(
                        employee.competence,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
              if (stats.averageRating > 0)
                                  Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stats.averageRating.toStringAsFixed(1),
                                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                employee.ville,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Carte avec les détails de la demande en cours
  Widget _buildRequestDetailsCard(RequestModel request, RequestFlowState flowState) {
    // Récupérer le nom de la catégorie
    String categoryName = '';
    try {
      final category = _categorieController.categories.firstWhereOrNull(
        (cat) => cat.id == request.categorieId,
      );
      categoryName = category?.nom ?? 'Catégorie inconnue';
    } catch (_) {
      categoryName = 'Catégorie inconnue';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.nightSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  categoryName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: flowState == RequestFlowState.pending
                      ? AppColors.warning.withOpacity(0.2)
                      : AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  flowState == RequestFlowState.pending
                      ? 'status_pending'.tr
                      : 'status_accepted'.tr,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: flowState == RequestFlowState.pending
                        ? AppColors.warning
                        : AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'your_request_in_progress'.tr,
            style: AppTextStyles.h4.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            request.description,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request.address,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bouton pour annuler la demande
  Widget _buildCancelRequestButton(RequestModel request) {
    return InDriveButton(
                                  label: 'cancel_request'.tr,
                                  onPressed: _requestController.isLoading.value
                                      ? null
                                      : () => _showCancelRequestDialog(context, request),
                                  variant: InDriveButtonVariant.ghost,
    );
  }

  /// Actions disponibles quand la demande est acceptée
  Widget _buildAcceptedRequestActions(RequestModel request) {
    return FutureBuilder<MissionModel?>(
      future: _missionRepository.getMissionByRequestId(request.id),
      builder: (context, snapshot) {
        final mission = snapshot.data;
        final canFinish = mission != null && mission.statutMission.toLowerCase() != 'completed';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canFinish)
              Obx(
                () {
                  // mission is guaranteed to be non-null when canFinish is true
                  final nonNullMission = mission;
                  return InDriveButton(
                    label: 'finish_request'.tr,
                    onPressed: _missionController.isLoading.value
                        ? null
                        : () => _finishRequest(request, nonNullMission),
                    variant: InDriveButtonVariant.primary,
                  );
                },
              ),
            if (canFinish) const SizedBox(height: 12),
            InDriveButton(
              label: 'open_chat'.tr,
              onPressed: () => _openChat(request),
              variant: canFinish ? InDriveButtonVariant.ghost : InDriveButtonVariant.primary,
            ),
            const SizedBox(height: 12),
            InDriveButton(
              label: 'cancel_request'.tr,
              onPressed: _requestController.isLoading.value
                  ? null
                  : () => _showCancelRequestDialog(context, request),
              variant: InDriveButtonVariant.ghost,
            ),
          ],
        );
      },
    );
  }

  void _showCancelRequestDialog(BuildContext context, RequestModel request) {
    // Si la demande est assignée à un employé, afficher le formulaire de rapport
    if (request.employeeId != null && request.statut.toLowerCase() == 'accepted') {
      _showCancellationReportForm(context, request);
    } else {
      // Sinon, afficher le dialogue de confirmation simple
      Get.dialog(
        Obx(
          () => InDriveDialogTemplate(
            title: 'cancel_request_dialog_title'.tr,
            message: 'cancel_request_dialog_content'.tr,
            primaryLabel: _requestController.isLoading.value ? 'loading'.tr : 'yes_cancel'.tr,
            danger: true,
            onPrimary: _requestController.isLoading.value
                ? () {}
                : () async {
                    final reason = await _requestController.cancelRequest(request.id);
                    if (reason != null) {
                      try {
                        await _requestFlowController.markCanceled();
                      } catch (e) {
                        // Ignorer les erreurs si le RequestFlowController n'a pas de demande active
                      }
                      // Réinitialiser l'état local
                      if (mounted) {
                        _selectedEmployeeNotifier.value = null;
                        _acceptedEmployeesNotifier.value = [];
                        _employeeStatistics.clear();
                        _currentRequestForAnimation = null;
                      }
                    }
                    Get.back();
                  },
            secondaryLabel: 'no'.tr,
            onSecondary: _requestController.isLoading.value
                ? null
                : () => Get.back(),
          ),
        ),
        barrierDismissible: false,
      );
    }
  }

  /// Afficher le formulaire de rapport d'annulation
  void _showCancellationReportForm(BuildContext context, RequestModel request) async {
    // Charger le nom de l'employé
    String? employeeName;
    try {
      final employee = await _employeeRepository.getEmployeeById(request.employeeId!);
      employeeName = employee?.nomComplet;
    } catch (e) {
      debugPrint('Erreur lors du chargement de l\'employé: $e');
    }

    Get.dialog(
      CancellationReportDialog(
        requestId: request.id,
        employeeName: employeeName,
        onConfirm: (reason) async {
          Get.back(); // Fermer le dialogue de rapport
          
          // Annuler la demande avec la raison
          final result = await _requestController.cancelRequest(request.id, cancellationReason: reason);
          
          if (result != null) {
            // Créer le rapport d'annulation
            await _createCancellationReport(request, reason);
            
            // Notifier l'employé
            await _notifyEmployeeAboutCancellation(request, reason, employeeName);
            
            try {
              await _requestFlowController.markCanceled();
            } catch (e) {
              // Ignorer les erreurs si le RequestFlowController n'a pas de demande active
            }
            
            // Réinitialiser l'état local
            if (mounted) {
              _selectedEmployeeNotifier.value = null;
              _acceptedEmployeesNotifier.value = [];
              _employeeStatistics.clear();
              _currentRequestForAnimation = null;
            }
          }
        },
      ),
      barrierDismissible: false,
    );
  }

  /// Créer le rapport d'annulation
  Future<void> _createCancellationReport(RequestModel request, String reason) async {
    try {
      final reportId = FirebaseFirestore.instance.collection('cancellation_reports').doc().id;
      final now = DateTime.now();
      
      final report = CancellationReportModel(
        id: reportId,
        requestId: request.id,
        clientId: request.clientId,
        employeeId: request.employeeId,
        clientReason: reason,
        employeeNotificationReason: reason, // Même raison pour l'employé
        createdAt: now,
        updatedAt: now,
      );

      await _cancellationReportRepository.createReport(report);
      debugPrint('[ClientDashboard] Rapport d\'annulation créé: $reportId');
    } catch (e) {
      debugPrint('[ClientDashboard] Erreur lors de la création du rapport: $e');
      // Ne pas bloquer l'annulation si le rapport échoue
    }
  }

  /// Notifier l'employé de l'annulation
  Future<void> _notifyEmployeeAboutCancellation(
    RequestModel request,
    String reason,
    String? employeeName,
  ) async {
    try {
      if (request.employeeId == null) return;

      // Récupérer l'employé pour obtenir son userId
      final employee = await _employeeRepository.getEmployeeById(request.employeeId!);
      if (employee?.userId == null) return;

      // Envoyer une notification locale à l'employé
      await _notificationService.showNotification(
        id: 'cancellation_${request.id}'.hashCode,
        title: 'request_cancelled_notification_title'.tr,
        body: 'request_cancelled_notification_body'.tr.replaceAll('{reason}', reason),
        payload: request.id,
        channelId: 'general_channel',
        importance: Importance.high,
        priority: Priority.high,
      );

      debugPrint('[ClientDashboard] Notification envoyée à l\'employé ${employee?.userId}');
    } catch (e) {
      debugPrint('[ClientDashboard] Erreur lors de l\'envoi de la notification: $e');
      // Ne pas bloquer l'annulation si la notification échoue
    }
  }

  Future<void> _openChat(RequestModel request) async {
    if (request.employeeId == null || request.statut.toLowerCase() != 'accepted') {
      SnackbarHelper.showInfo('chat_not_available'.tr);
      return;
    }
    try {
      final employee = await _employeeController.getEmployeeById(request.employeeId!);
      Get.toNamed(
        AppRoutes.AppRoutes.chat,
        arguments: ChatScreenArguments(
          requestId: request.id,
          clientId: request.clientId,
          employeeId: request.employeeId!,
          requestTitle: '${'request'.tr} #${request.id.substring(0, 8)}',
          requestStatus: request.statut,
          clientName: _authController.currentUser.value?.nomComplet,
          employeeName: employee?.nomComplet,
          employeeUserId: employee?.userId,
        ),
      );
    } catch (_) {
      Get.toNamed(
        AppRoutes.AppRoutes.chat,
        arguments: ChatScreenArguments(
          requestId: request.id,
          clientId: request.clientId,
          employeeId: request.employeeId!,
          requestTitle: '${'request'.tr} #${request.id.substring(0, 8)}',
          requestStatus: request.statut,
          clientName: _authController.currentUser.value?.nomComplet,
        ),
      );
    }
  }

  /// Terminer une demande
  Future<void> _finishRequest(RequestModel request, MissionModel mission) async {
    // Show dialog for price feedback
    final result = await _showFinishDialog(mission);
    if (result == null) return;
    
    final price = result['price'] as double;
    final rating = result['rating'] as double?;
    final comment = result['comment'] as String?;
    
    try {
      // Generate QR code token
      final token = await _qrCodeService.createFinishToken(
        requestId: request.id,
        clientId: request.clientId,
        employeeId: request.employeeId!,
        price: price,
        rating: rating,
        comment: comment,
      );
      
      // Show QR code dialog
      await _showQRCodeDialog(token, request.id);
    } catch (e, stackTrace) {
      Logger.logError('ClientDashboardScreen._finishRequest', e, stackTrace);
      SnackbarHelper.showError('${'error_finishing'.tr}: $e');
    }
  }

  /// Afficher le dialogue de fin de demande
  Future<Map<String, dynamic>?> _showFinishDialog(MissionModel mission) async {
    final priceController = TextEditingController(text: mission.prixMission.toStringAsFixed(2));
    final commentController = TextEditingController();
    final selectedRating = ValueNotifier<double?>(null);
    
    return await Get.dialog<Map<String, dynamic>>(
      Dialog(
        backgroundColor: AppColors.nightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
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
                    style: AppTextStyles.h3.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  
                  // Price input
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: '${'price'.tr} (€)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.attach_money, color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      fillColor: AppColors.nightSecondary,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Rating
                  Text(
                    '${'rating'.tr} (${'optional'.tr})',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  buildRatingStars(),
                  const SizedBox(height: 16),
                  
                  // Comment
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'comment_hint'.tr,
                      hintText: 'comment_hint'.tr,
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      fillColor: AppColors.nightSecondary,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: InDriveButton(
                          label: 'cancel'.tr,
                          onPressed: () => Get.back(),
                          variant: InDriveButtonVariant.ghost,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InDriveButton(
                          label: 'finish'.tr,
                          onPressed: () {
                            final price = double.tryParse(priceController.text);
                            if (price == null || price < 0) {
                              SnackbarHelper.showError('enter_valid_price'.tr);
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
                          variant: InDriveButtonVariant.primary,
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

  /// Afficher le dialogue QR code
  Future<void> _showQRCodeDialog(String token, String requestId) async {
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
          // The stream will update automatically, but we can mark as completed
          _requestFlowController.markCompleted();
          SnackbarHelper.showSuccess('request_completed_success'.tr);
        }
      }
    });

    await Get.dialog(
      Dialog(
        backgroundColor: AppColors.nightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'scan_qr_code'.tr,
                style: AppTextStyles.h3.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: token,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'employee_scan_qr_code'.tr,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              InDriveButton(
                label: 'close'.tr,
                onPressed: () {
                  if (!dialogClosed) {
                    dialogClosed = true;
                    subscription?.cancel();
                    Get.back();
                    completer.complete();
                  }
                },
                variant: InDriveButtonVariant.ghost,
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    if (!dialogClosed) {
      subscription.cancel();
    }
  }

  /// Carte d'employé moderne
  Widget _buildEmployeeCard(EmployeeModel employee, EmployeeStatistics stats, RequestModel request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.nightSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 0,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Photo de profil
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  backgroundImage: employee.image != null
                      ? NetworkImage(employee.image!)
                      : null,
                  child: employee.image == null
                      ? Text(
                          employee.nomComplet.substring(0, 1).toUpperCase(),
                          style: AppTextStyles.h3.copyWith(color: AppColors.primaryLight),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Infos employé
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.nomComplet,
                        style: AppTextStyles.h4.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (employee.competence.isNotEmpty)
                        Text(
                          employee.competence,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            employee.ville,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Note avec design amélioré
                if (stats.averageRating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withOpacity(0.2),
                          AppColors.secondary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          stats.averageRating.toStringAsFixed(1),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Bouton Choisir
            InDriveButton(
              label: 'choose'.tr,
              onPressed: () => _acceptEmployee(employee.id),
              variant: InDriveButtonVariant.primary,
            ),
          ],
        ),
      ),
    );
  }
}
