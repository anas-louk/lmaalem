import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../components/indrive_card.dart';
import '../../components/indrive_button.dart';
import '../../components/custom_text_field.dart';
import '../../components/indrive_dialog_template.dart';
import '../../components/app_sidebar.dart';
import '../../components/language_switcher.dart';
import '../../core/helpers/snackbar_helper.dart';
import '../../core/enums/request_flow_state.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import 'history_screen.dart';
import 'chat_screen.dart';
import 'categories_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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

  RequestFlowController get _requestFlowController {
    try {
      return Get.find<RequestFlowController>();
    } catch (_) {
      return Get.put(RequestFlowController());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final flowState = _requestFlowController.currentState.value;
        final hasActiveRequest = flowState == RequestFlowState.pending || 
                                 flowState == RequestFlowState.accepted;
        
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Cacher la bottom navigation bar si une demande est en cours
          bottomNavigationBar: hasActiveRequest
              ? null
              : BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.history),
                      label: 'history'.tr,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home),
                      label: 'home'.tr,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.category),
                      label: 'categories'.tr,
                    ),
                  ],
                ),
        );
      },
    );
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
  String? _loadedUserId;

  // Formulaire de demande
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _selectedCategorieId;
  String? _currentAddress;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  List<File> _selectedImages = [];

  // Employés acceptés (gérés par stream temps réel)
  final ValueNotifier<List<EmployeeModel>> _acceptedEmployeesNotifier = ValueNotifier<List<EmployeeModel>>([]);
  final Map<String, EmployeeStatistics> _employeeStatistics = {};
  final ValueNotifier<bool> _isLoadingEmployees = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isConnected = ValueNotifier<bool>(true);
  
  // Employé sélectionné (si demande acceptée)
  EmployeeModel? _selectedEmployee;
  
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
        setState(() {
          _latitude = locationData['latitude'] as double;
          _longitude = locationData['longitude'] as double;
          _currentAddress = locationData['address'] as String;
        });
      }
    } catch (e) {
      // Silently fail - location will be requested when submitting
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = true;
      });

      final locationData = await _locationService.getCurrentLocationWithAddress();

      if (mounted) {
        setState(() {
          _latitude = locationData['latitude'] as double;
          _longitude = locationData['longitude'] as double;
          _currentAddress = locationData['address'] as String;
          _isLoadingLocation = false;
        });
        SnackbarHelper.showSuccess('location_retrieved'.tr);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
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

        // Charger les statistiques pour les nouveaux employés
        for (final employee in employees) {
          if (!_employeeStatistics.containsKey(employee.id)) {
            final stats = await _statisticsService.getEmployeeStatisticsByStringId(employee.id);
            if (mounted) {
              _employeeStatistics[employee.id] = stats;
            }
          }
        }

        if (mounted) {
          // Mettre à jour la liste (les animations seront gérées par AnimatedSwitcher)
          _acceptedEmployeesNotifier.value = employees;
          _isLoadingEmployees.value = false;
        }
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

    if (_selectedCategorieId == null) {
      SnackbarHelper.showError('category_required'.tr);
      return;
    }

    if (_latitude == null || _longitude == null || _currentAddress == null) {
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      final requestId = FirebaseFirestore.instance.collection('requests').doc().id;

      // Uploader les images si disponibles
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        for (int i = 0; i < _selectedImages.length; i++) {
          final imageUrl = await _storageService.uploadRequestImage(
            requestId: requestId,
            imageFile: _selectedImages[i],
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
        latitude: _latitude!,
        longitude: _longitude!,
        address: _currentAddress!,
        categorieId: _selectedCategorieId!,
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
          setState(() {
            _selectedCategorieId = null;
            _selectedImages = [];
          });
          
        // Le stream temps réel sera initialisé automatiquement dans build()
          
          SnackbarHelper.showSuccess('request_submitted_success'.tr);
        }
      }
    } catch (e) {
      SnackbarHelper.showError('${'error_submitting'.tr}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _acceptEmployee(String employeeId) async {
    final activeRequest = _requestFlowController.activeRequest.value;
    if (activeRequest == null) return;

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
    });

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
        await _requestFlowController.markAccepted(
          AcceptedEmployeeSummary(
            id: employeeId,
            name: _selectedEmployee?.nomComplet,
            service: _selectedEmployee?.competence,
            city: _selectedEmployee?.ville,
            rating: _employeeStatistics[employeeId]?.averageRating,
            photoUrl: _selectedEmployee?.image,
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
        setState(() {
          _isSubmitting = false;
        });
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
        setState(() {
          _selectedEmployee = employee;
        });
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
        setState(() {
          _selectedImages = images.map((image) => File(image.path)).toList();
        });
      }
    } catch (e) {
      SnackbarHelper.showError('${'error_selecting_images'.tr}: $e');
    }
  }

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

          // Écouter les changements de la demande en temps réel
          if (activeRequest != null && (flowState == RequestFlowState.pending || flowState == RequestFlowState.accepted)) {
            // Stream de la demande pour les mises à jour d'état
            _requestStreamSubscription?.cancel();
            _requestStreamSubscription = _requestRepository.streamRequest(activeRequest.id).listen((request) {
              if (request != null && mounted) {
                // Si un employé est sélectionné, le charger
                if (request.employeeId != null && _selectedEmployee == null) {
                  _loadSelectedEmployee(request.employeeId!);
                }
              }
            });
            
            // Initialiser le stream temps réel pour les employés acceptés
            if (flowState == RequestFlowState.pending) {
              _currentRequestForAnimation = activeRequest;
              _initRealtimeEmployeesStream(activeRequest.id);
            }
            
            // Charger l'employé sélectionné si nécessaire
            if (flowState == RequestFlowState.accepted && activeRequest.employeeId != null && _selectedEmployee == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _loadSelectedEmployee(activeRequest.employeeId!);
                }
              });
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

          // Affichage conditionnel unifié sur la même page
          return _buildUnifiedView(user, flowState, activeRequest);
        },
      ),
    );
  }

  /// Vue unifiée avec affichage conditionnel selon l'état
  Widget _buildUnifiedView(user, RequestFlowState flowState, RequestModel? activeRequest) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section A : Header client OU Liste employés
          if (flowState == RequestFlowState.idle)
            _buildUserHeader(user)
          else if (flowState == RequestFlowState.pending && activeRequest != null)
            _buildAcceptedEmployeesList(activeRequest)
          else if (flowState == RequestFlowState.accepted && activeRequest != null)
            _selectedEmployee != null
                ? _buildSelectedEmployeeHeader(_selectedEmployee!)
                : const LoadingWidget()
          else
            _buildUserHeader(user),
          
          const SizedBox(height: 24),

          // Section B : Formulaire OU Infos demande
          if (flowState == RequestFlowState.idle)
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCategorySelector(),
                  const SizedBox(height: 24),
                  _buildDescriptionForm(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                ],
              ),
            )
          else if (activeRequest != null)
            _buildRequestDetailsCard(activeRequest, flowState),
          
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

  /// Header avec infos client + localisation
  Widget _buildUserHeader(user) {
    return InDriveCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Photo de profil
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                child: Text(
                  user.nomComplet.substring(0, 1).toUpperCase(),
                  style: AppTextStyles.h3.copyWith(color: AppColors.primary),
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
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.localisation.isNotEmpty ? user.localisation : 'Localisation non définie',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Localisation
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentAddress ?? 'Localisation non disponible',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              if (_isLoadingLocation)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _getCurrentLocation,
                  tooltip: 'refresh_location'.tr,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sélecteur de catégories avec icônes circulaires
  Widget _buildCategorySelector() {
    return Obx(
      () {
        if (_categorieController.isLoading.value) {
          return const LoadingWidget();
        }

        if (_categorieController.categories.isEmpty) {
          return EmptyState(
            icon: Icons.category_outlined,
            title: 'no_categories'.tr,
            message: 'no_categories_message'.tr,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'select_category'.tr,
              style: AppTextStyles.h4,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _categorieController.categories.map((categorie) {
                final isSelected = _selectedCategorieId == categorie.id;
                return GestureDetector(
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _selectedCategorieId = categorie.id;
                      });
                    }
                  },
                  child: Container(
                    width: 80,
                    child: Column(
                      children: [
                        // Icône circulaire
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.secondary.withOpacity(0.15)
                                : AppColors.greyLight,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.secondary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              categorie.nom.substring(0, 1).toUpperCase(),
                              style: AppTextStyles.h3.copyWith(
                                color: isSelected
                                    ? AppColors.secondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Nom de la catégorie
                        Text(
                          categorie.nom,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isSelected
                                ? AppColors.secondary
                                : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  /// Formulaire de description
  Widget _buildDescriptionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'request_description_label'.tr,
          style: AppTextStyles.h4,
        ),
        const SizedBox(height: 12),
        InDriveCard(
          padding: EdgeInsets.zero,
          child: CustomTextField(
            controller: _descriptionController,
            hint: 'request_description_hint'.tr,
            maxLines: 5,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'description_required'.tr;
              }
              return null;
            },
          ),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImages[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            if (mounted) {
                              setState(() {
                                _selectedImages.removeAt(index);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.add_photo_alternate),
          label: Text('add_images'.tr),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  /// Bouton de soumission
  Widget _buildSubmitButton() {
    return InDriveButton(
      label: _isSubmitting ? 'submitting'.tr : 'confirm_request'.tr,
      onPressed: _isSubmitting ? null : _submitRequest,
      variant: InDriveButtonVariant.primary,
    );
  }

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
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'select_employee_message'.tr,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
    
    return InDriveCard(
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
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 4),
                    if (employee.competence.isNotEmpty)
                      Text(
                        employee.competence,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
              if (stats.averageRating > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
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
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                employee.ville,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
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

    return InDriveCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  categoryName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: flowState == RequestFlowState.pending
                      ? AppColors.warning.withOpacity(0.15)
                      : AppColors.success.withOpacity(0.15),
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
            style: AppTextStyles.h4,
          ),
          const SizedBox(height: 12),
          Text(
            request.description,
            style: AppTextStyles.bodyMedium,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InDriveButton(
          label: 'open_chat'.tr,
          onPressed: () => _openChat(request),
          variant: InDriveButtonVariant.primary,
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
  }

  void _showCancelRequestDialog(BuildContext context, RequestModel request) {
    Get.dialog(
      Obx(
        () => InDriveDialogTemplate(
          title: 'cancel_request_dialog_title'.tr,
          message: 'cancel_request_dialog_content'.tr,
          primaryLabel: _requestController.isLoading.value ? 'loading'.tr : 'yes_cancel'.tr,
          onPrimary: _requestController.isLoading.value
              ? () {}
              : () async {
                  final success = await _requestController.cancelRequest(request.id);
                  if (success) {
                    try {
                      await _requestFlowController.markCanceled();
                    } catch (e) {
                      // Ignorer les erreurs si le RequestFlowController n'a pas de demande active
                    }
                    // Réinitialiser l'état local
                    if (mounted) {
                      setState(() {
                        _selectedEmployee = null;
                      });
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
          danger: true,
        ),
      ),
      barrierDismissible: false,
    );
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

  /// Carte d'employé moderne
  Widget _buildEmployeeCard(EmployeeModel employee, EmployeeStatistics stats, RequestModel request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InDriveCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Photo de profil
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  backgroundImage: employee.image != null
                      ? NetworkImage(employee.image!)
                      : null,
                  child: employee.image == null
                      ? Text(
                          employee.nomComplet.substring(0, 1).toUpperCase(),
                          style: AppTextStyles.h3.copyWith(color: AppColors.primary),
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
                        style: AppTextStyles.h4,
                      ),
                      const SizedBox(height: 4),
                      if (employee.competence.isNotEmpty)
                        Text(
                          employee.competence,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            employee.ville,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Note
                if (stats.averageRating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
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
