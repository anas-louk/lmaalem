import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../controllers/request_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/categorie_controller.dart';
import '../../data/models/request_model.dart';
import '../../data/models/categorie_model.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/location_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/helpers/snackbar_helper.dart';
import '../../components/custom_text_field.dart';
import '../../components/loading_widget.dart';
import '../../components/indrive_app_bar.dart';
import '../../components/indrive_card.dart';
import '../../components/indrive_button.dart';
import '../../components/indrive_section_title.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Écran de soumission de demande pour les clients
class RequestSubmissionScreen extends StatefulWidget {
  final String categorieId;

  const RequestSubmissionScreen({
    super.key,
    required this.categorieId,
  });

  @override
  State<RequestSubmissionScreen> createState() => _RequestSubmissionScreenState();
}

class _RequestSubmissionScreenState extends State<RequestSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _requestController = Get.put(RequestController());
  final _authController = Get.find<AuthController>();
  final _categorieController = Get.find<CategorieController>();
  final _storageService = StorageService();
  final _locationService = LocationService();

  List<File> _selectedImages = [];
  String? _address;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  CategorieModel? _categorie;
  bool _initialLocationRequested = false;

  @override
  void initState() {
    super.initState();
    _loadCategorie();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoFetchLocation());
  }

  void _loadCategorie() {
    _categorie = _categorieController.categories.firstWhereOrNull(
      (cat) => cat.id == widget.categorieId,
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _autoFetchLocation() {
    if (_initialLocationRequested) return;
    _initialLocationRequested = true;
    _getCurrentLocation(showSuccessToast: false);
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images.map((image) => File(image.path)).toList();
        });
      }
    } catch (e) {
      SnackbarHelper.showError('${'error_selecting_images'.tr}: $e');
    }
  }

  Future<void> _getCurrentLocation({bool showSuccessToast = true}) async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });

      final locationData = await _locationService.getCurrentLocationWithAddress();

      setState(() {
        _latitude = locationData['latitude'] as double;
        _longitude = locationData['longitude'] as double;
        _address = locationData['address'] as String;
        _isLoadingLocation = false;
      });

      if (showSuccessToast) {
        SnackbarHelper.showSuccess('location_retrieved'.tr);
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      
      // Handle LocationException with dialog to open settings
      if (e is LocationException && e.canOpenSettings) {
        _showLocationErrorDialog(e.message);
      } else {
        SnackbarHelper.showError(e.toString());
      }
    }
  }
  
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
      // Check if GPS is disabled, then open appropriate settings
      final isGpsEnabled = await _locationService.isLocationServiceEnabled();
      if (!isGpsEnabled) {
        await _locationService.openLocationSettings();
      } else {
        await _locationService.openAppSettings();
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_latitude == null || _longitude == null || _address == null) {
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

    try {
      // Créer l'ID de la demande
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
        address: _address!,
        categorieId: widget.categorieId,
        clientId: _authController.currentUser.value!.id,
        statut: 'Pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Sauvegarder la demande
      final success = await _requestController.createRequest(request);

      if (success) {
        // Naviguer vers le dashboard client (home)
        Get.offAllNamed(AppRoutes.AppRoutes.clientDashboard);
        SnackbarHelper.showSuccess('request_submitted_success'.tr);
      }
    } catch (e) {
      SnackbarHelper.showError('${'error_submitting'.tr}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InDriveAppBar(
        title: _categorie?.nom ?? 'new_request_title'.tr,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Get.back(),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (_requestController.isLoading.value) {
            return const LoadingWidget();
          }

          final bottomPadding = MediaQuery.of(context).padding.bottom;
          return Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + bottomPadding),
            children: [
              if (_categorie != null) ...[
                InDriveCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: Text(
                          _categorie!.nom.substring(0, 1).toUpperCase(),
                          style: AppTextStyles.h3.copyWith(color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _categorie!.nom,
                          style: AppTextStyles.h3,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.toNamed(AppRoutes.AppRoutes.categories),
                        icon: const Icon(Icons.swap_horiz),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              InDriveSectionTitle(
                title: 'request_description_label'.tr,
                subtitle: 'request_description_hint'.tr,
              ),
              const SizedBox(height: 12),
              InDriveCard(
                child: CustomTextField(
                  controller: _descriptionController,
                  hint: 'request_description_hint'.tr,
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'description_required'.tr;
                    }
                    if (value.trim().length < 10) {
                      return 'description_too_short'.tr;
                    }
                    return null;
                  },
                  fillColor: Colors.transparent,
                  textColor: Theme.of(context).colorScheme.onSurface,
                  hintColor: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
                  borderColor: Colors.transparent,
                ),
              ),
              const SizedBox(height: 24),
              InDriveSectionTitle(
                title: 'images_optional'.tr,
                subtitle: 'add_images'.tr,
              ),
              const SizedBox(height: 12),
              if (_selectedImages.isEmpty)
                GestureDetector(
                  onTap: _pickImages,
                  child: InDriveCard(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 48, color: AppColors.primary),
                        const SizedBox(height: 12),
                        Text(
                          'add_images'.tr,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      if (index == _selectedImages.length) {
                        return GestureDetector(
                          onTap: _pickImages,
                          child: InDriveCard(
                            padding: const EdgeInsets.all(12),
                            borderRadius: 20,
                            child: const Icon(Icons.add, size: 32),
                          ),
                        );
                      }
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              _selectedImages[index],
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedImages.removeAt(index));
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              InDriveSectionTitle(
                title: 'location'.tr,
                subtitle: 'location_required'.tr,
                actionText: 'refresh'.tr,
                onActionTap: _isLoadingLocation ? null : () => _getCurrentLocation(showSuccessToast: false),
              ),
              const SizedBox(height: 12),
              InDriveCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoadingLocation)
                      Row(
                        children: [
                          const CircularProgressIndicator(strokeWidth: 2),
                          const SizedBox(width: 12),
                          Text('getting_location'.tr),
                        ],
                      )
                    else if (_address != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _address!,
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Lat: ${_latitude!.toStringAsFixed(5)}, Lng: ${_longitude!.toStringAsFixed(5)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'no_location_selected'.tr,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    const SizedBox(height: 12),
                    InDriveButton(
                      label: _isLoadingLocation ? 'getting_location'.tr : 'get_location'.tr,
                      onPressed: _isLoadingLocation ? null : () => _getCurrentLocation(showSuccessToast: true),
                      isLoading: _isLoadingLocation,
                      leadingIcon: Icons.my_location,
                      variant: InDriveButtonVariant.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              InDriveButton(
                label: 'submit_request_button'.tr,
                onPressed: _requestController.isLoading.value ? null : _submitRequest,
                isLoading: _requestController.isLoading.value,
                height: 56,
              ),
            ],
          ),
        );
        }),
      ),
    );
  }
}

