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
import '../../components/custom_button.dart';
import '../../components/custom_text_field.dart';
import '../../components/loading_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCategorie();
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

  Future<void> _getCurrentLocation() async {
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

      SnackbarHelper.showSuccess('location_retrieved'.tr);
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
      appBar: AppBar(
        title: Text(_categorie?.nom ?? 'new_request_title'.tr),
      ),
      body: Obx(() {
        if (_requestController.isLoading.value) {
          return const LoadingWidget();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Catégorie info
                if (_categorie != null)
                  Card(
                    color: AppColors.primaryLight.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              _categorie!.nom[0].toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _categorie!.nom,
                              style: AppTextStyles.h4.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Description field
                CustomTextField(
                  controller: _descriptionController,
                  label: 'request_description_label'.tr,
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
                ),
                const SizedBox(height: 24),

                // Images section
                Text(
                  'images_optional'.tr,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (_selectedImages.isEmpty)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.greyLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.grey,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: AppColors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'add_images'.tr,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _selectedImages[index],
                                      width: 150,
                                      height: 150,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedImages.removeAt(index);
                                        });
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
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: Text('add_more_images'.tr),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Location section
                Text(
                  'location'.tr,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_address == null)
                          Text(
                            'no_location_selected'.tr,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                      _address!,
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        CustomButton(
                          onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                          text: _isLoadingLocation
                              ? 'getting_location'.tr
                              : 'get_location'.tr,
                          isLoading: _isLoadingLocation,
                          backgroundColor: AppColors.secondary,
                          height: 45,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit button
                CustomButton(
                  onPressed: _submitRequest,
                  text: 'submit_request_button'.tr,
                  isLoading: _requestController.isLoading.value,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      }),
    );
  }
}

