import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/categorie_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../components/custom_button.dart';
import '../../components/custom_text_field.dart';
import '../../components/language_switcher.dart';
import '../../components/indrive_app_bar.dart';
import '../../components/indrive_card.dart';
import '../../components/indrive_dialog_template.dart';
import '../../components/indrive_button.dart';
import '../../data/models/user_model.dart';
import '../../core/helpers/snackbar_helper.dart';
import '../../utils/battery_optimization.dart';
import '../../core/services/employee_statistics_service.dart';
import '../../widgets/employee_statistics_widget.dart';
import '../../data/models/employee_statistics.dart';

/// Écran de profil
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController _authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.night,
      appBar: InDriveAppBar(
        title: 'profile'.tr,
        actions: const [
          LanguageSwitcher(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Obx(
          () {
            final user = _authController.currentUser.value;

          if (user == null) {
            return Center(
              child: Text(
                'user_not_connected'.tr,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white70,
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Carte d'information utilisateur moderne
                InDriveCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Avatar moderne
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
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
                                  color: AppColors.primary.withOpacity(0.5),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 94,
                                height: 94,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.nightSurface,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    user.nomComplet.isNotEmpty ? user.nomComplet[0].toUpperCase() : 'U',
                                    style: AppTextStyles.h1.copyWith(
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Badge de statut
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                                border: Border.all(
                                  color: AppColors.nightSurface,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Nom
                      Text(
                        user.nomComplet,
                        style: AppTextStyles.h2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Badge de type
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.3),
                              AppColors.primaryDark.withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              user.type.toLowerCase() == 'client'
                                  ? Icons.person_outline_rounded
                                  : Icons.work_outline_rounded,
                              size: 16,
                              color: AppColors.primaryLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              user.type.toLowerCase() == 'client'
                                  ? 'client_type'.tr
                                  : 'employee_type'.tr,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryLight,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Informations utilisateur
                      _buildInfoRow(
                        icon: Icons.location_on_rounded,
                        label: 'user_location'.tr,
                        value: user.localisation,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.phone_rounded,
                        label: 'phone_number'.tr,
                        value: user.tel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Update Information button (for both Employees and Clients)
                Obx(
                  () => CustomButton(
                    onPressed: _authController.isLoading.value
                        ? null
                        : () {
                            _showUpdateInfoDialog(context, _authController, user);
                          },
                    text: 'edit_profile'.tr,
                    isLoading: _authController.isLoading.value,
                    backgroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // Switch to Employee button (only for Clients)
                if (user.type.toLowerCase() == 'client')
                  Obx(
                    () => CustomButton(
                      onPressed: _authController.isLoading.value
                          ? null
                          : () async {
                              // Vérifier si l'Employee existe déjà
                              final existingEmployee = await _authController.getExistingEmployee(user.id);
                              if (existingEmployee != null) {
                                // Si l'Employee existe, switcher directement
                                await _authController.switchToEmployeeDirectly();
                              } else {
                                // Sinon, afficher le formulaire
                                _showSwitchToEmployeeDialog(context, _authController);
                              }
                            },
                      text: 'switch_to_employee'.tr,
                      isLoading: _authController.isLoading.value,
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                if (user.type.toLowerCase() == 'client') const SizedBox(height: 16),

                // Switch to Client button (only for Employees)
                if (user.type.toLowerCase() == 'employee')
                  Obx(
                    () => CustomButton(
                      onPressed: _authController.isLoading.value
                          ? null
                          : () {
                              _showSwitchToClientDialog(context, _authController);
                            },
                      text: 'switch_to_client'.tr,
                      isLoading: _authController.isLoading.value,
                      backgroundColor: AppColors.secondary,
                    ),
                  ),
                if (user.type.toLowerCase() == 'employee') const SizedBox(height: 16),

                // Statistics Section (for employees only)
                if (user.type.toLowerCase() == 'employee') ...[
                  InDriveCard(
                    padding: const EdgeInsets.all(20),
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
                                Icons.bar_chart_rounded,
                                color: AppColors.primaryLight,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Statistics',
                              style: AppTextStyles.h4.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _EmployeeStatisticsSection(employeeId: user.id),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Settings Section
                InDriveCard(
                  padding: const EdgeInsets.all(20),
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
                              Icons.settings_rounded,
                              color: AppColors.primaryLight,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'settings'.tr,
                            style: AppTextStyles.h4.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Battery Optimization Setting
                      _BatteryOptimizationTile(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Delete account button
                Obx(
                  () => CustomButton(
                    onPressed: _authController.isLoading.value
                        ? null
                        : () {
                            _showDeleteAccountDialog(context, _authController);
                          },
                    text: 'delete_account'.tr,
                    isLoading: _authController.isLoading.value,
                    backgroundColor: AppColors.error,
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

  void _showSwitchToEmployeeDialog(
    BuildContext context,
    AuthController authController,
  ) async {
    final villeController = TextEditingController();
    final competenceController = TextEditingController();
    final categorieController = Get.put(CategorieController());
    final selectedCategorieId = Rx<String?>(null);

    // Charger les catégories si elles ne sont pas déjà chargées
    if (categorieController.categories.isEmpty) {
      await categorieController.loadAllCategories();
    }

    // Vérifier si l'Employee existe déjà et pré-remplir les champs
    final currentUser = authController.currentUser.value;
    if (currentUser != null) {
      final existingEmployee = await authController.getExistingEmployee(currentUser.id);
      if (existingEmployee != null) {
        // Pré-remplir avec les données existantes
        selectedCategorieId.value = existingEmployee.categorieId;
        villeController.text = existingEmployee.ville;
        competenceController.text = existingEmployee.competence;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.nightSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'become_employee_title'.tr,
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Obx(
                            () => DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'category'.tr,
                                border: const OutlineInputBorder(),
                              ),
                              value: selectedCategorieId.value,
                              items: categorieController.categories.map((categorie) {
                                return DropdownMenuItem<String>(
                                  value: categorie.id,
                                  child: Text(categorie.nom),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedCategorieId.value = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'category_required'.tr;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: villeController,
                            label: 'city'.tr,
                            hint: 'city_hint'.tr,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'city_required'.tr;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: competenceController,
                            label: 'competence'.tr,
                            hint: 'competence_hint'.tr,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'competence_required'.tr;
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Obx(
                    () => Column(
                      children: [
                        InDriveButton(
                          label: 'confirm'.tr,
                          onPressed: authController.isLoading.value
                              ? null
                              : () async {
                                  if (selectedCategorieId.value != null &&
                                      villeController.text.isNotEmpty &&
                                      competenceController.text.isNotEmpty) {
                                    final success = await authController.switchToEmployee(
                                      categorieId: selectedCategorieId.value!,
                                      ville: villeController.text,
                                      competence: competenceController.text,
                                    );

                                    if (success) {
                                      Get.back(); // Close dialog
                                      // The redirect will happen automatically via loadUser
                                    }
                                  } else {
                                    SnackbarHelper.showError('fill_all_fields'.tr);
                                  }
                                },
                          variant: InDriveButtonVariant.primary,
                        ),
                        const SizedBox(height: 12),
                        InDriveButton(
                          label: 'cancel'.tr,
                          onPressed: () => Get.back(),
                          variant: InDriveButtonVariant.ghost,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSwitchToClientDialog(
    BuildContext context,
    AuthController authController,
  ) {
    showDialog(
      context: context,
      builder: (context) => InDriveDialogTemplate(
        title: 'become_client_title'.tr,
        message: 'become_client_message'.tr,
        primaryLabel: 'confirm'.tr,
        onPrimary: () async {
          final success = await authController.switchToClient();

          if (success) {
            Get.back(); // Close dialog
            // The redirect will happen automatically via loadUser
          }
        },
        secondaryLabel: 'cancel'.tr,
        onSecondary: () => Get.back(),
        danger: false,
      ),
    );
  }

  void _showUpdateInfoDialog(
    BuildContext context,
    AuthController authController,
    UserModel user,
  ) async {
    final nomCompletController = TextEditingController(text: user.nomComplet);
    final localisationController = TextEditingController(text: user.localisation);
    final telController = TextEditingController(text: user.tel);
    
    // Employee-specific controllers
    final villeController = TextEditingController();
    final competenceController = TextEditingController();
    final bioController = TextEditingController();
    final categorieController = Get.put(CategorieController());
    final selectedCategorieId = Rx<String?>(null);

    final isEmployee = user.type.toLowerCase() == 'employee';

    // Load categories if employee
    if (isEmployee) {
      if (categorieController.categories.isEmpty) {
        await categorieController.loadAllCategories();
      }

      // Load employee data if exists
      final existingEmployee = await authController.getExistingEmployee(user.id);
      if (existingEmployee != null) {
        selectedCategorieId.value = existingEmployee.categorieId;
        villeController.text = existingEmployee.ville;
        competenceController.text = existingEmployee.competence;
        bioController.text = existingEmployee.bio ?? '';
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.nightSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'update_info_title'.tr,
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomTextField(
                            controller: nomCompletController,
                            label: 'full_name'.tr,
                            hint: 'name_hint_profile'.tr,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'name_required'.tr;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: localisationController,
                            label: 'location'.tr,
                            hint: 'location_hint'.tr,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'location_required_field'.tr;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: telController,
                            label: 'phone'.tr,
                            hint: 'phone_hint'.tr,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'phone_required'.tr;
                              }
                              return null;
                            },
                          ),
                          if (isEmployee) ...[
                            const SizedBox(height: 16),
                            Obx(
                              () => DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'category'.tr,
                                  border: const OutlineInputBorder(),
                                ),
                                value: selectedCategorieId.value,
                                items: categorieController.categories.map((categorie) {
                                  return DropdownMenuItem<String>(
                                    value: categorie.id,
                                    child: Text(categorie.nom),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedCategorieId.value = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'category_required'.tr;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: villeController,
                              label: 'city'.tr,
                              hint: 'city_hint'.tr,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'city_required'.tr;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: competenceController,
                              label: 'competence'.tr,
                              hint: 'competence_hint'.tr,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'competence_required'.tr;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: bioController,
                              label: 'bio_optional'.tr,
                              hint: 'bio_hint'.tr,
                              maxLines: 3,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Obx(
                    () => Column(
                      children: [
                        InDriveButton(
                          label: 'save'.tr,
                          onPressed: authController.isLoading.value
                              ? null
                              : () async {
                                  // Validate common fields
                                  if (nomCompletController.text.isEmpty ||
                                      localisationController.text.isEmpty ||
                                      telController.text.isEmpty) {
                                    SnackbarHelper.showError('fill_required_fields'.tr);
                                    return;
                                  }

                                  // Validate employee fields if employee
                                  if (isEmployee) {
                                    if (selectedCategorieId.value == null ||
                                        villeController.text.isEmpty ||
                                        competenceController.text.isEmpty) {
                                      SnackbarHelper.showError('Veuillez remplir tous les champs obligatoires');
                                      return;
                                    }
                                  }

                                  final success = await authController.updateUserInfo(
                                    nomComplet: nomCompletController.text,
                                    localisation: localisationController.text,
                                    tel: telController.text,
                                    ville: isEmployee ? villeController.text : null,
                                    competence: isEmployee ? competenceController.text : null,
                                    bio: isEmployee ? bioController.text : null,
                                    categorieId: isEmployee ? selectedCategorieId.value : null,
                                  );

                                  if (success) {
                                    Get.back(); // Close dialog
                                  }
                                },
                          variant: InDriveButtonVariant.primary,
                        ),
                        const SizedBox(height: 12),
                        InDriveButton(
                          label: 'cancel'.tr,
                          onPressed: () => Get.back(),
                          variant: InDriveButtonVariant.ghost,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    AuthController authController,
  ) {
    showDialog(
      context: context,
      builder: (context) => InDriveDialogTemplate(
        title: 'delete_account'.tr,
        message: 'delete_account_confirmation'.tr,
        primaryLabel: 'delete'.tr,
        onPrimary: () async {
          final success = await authController.deleteAccount();
          if (success && context.mounted) {
            Get.back(); // Close dialog
          }
        },
        secondaryLabel: 'cancel'.tr,
        onSecondary: () => Get.back(),
        danger: true,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.nightSecondary,
        borderRadius: BorderRadius.circular(12),
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
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryLight,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget pour afficher et gérer l'optimisation de la batterie
class _BatteryOptimizationTile extends StatefulWidget {
  @override
  State<_BatteryOptimizationTile> createState() => _BatteryOptimizationTileState();
}

class _BatteryOptimizationTileState extends State<_BatteryOptimizationTile> {
  bool _isOptimizationDisabled = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkBatteryOptimization();
  }

  Future<void> _checkBatteryOptimization() async {
    setState(() {
      _isChecking = true;
    });
    try {
      final isIgnored = await BatteryOptimization.isIgnoringBatteryOptimizations();
      setState(() {
        _isOptimizationDisabled = isIgnored;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _isOptimizationDisabled = false;
        _isChecking = false;
      });
    }
  }

  Future<void> _handleBatteryOptimization() async {
    if (_isOptimizationDisabled) {
      // Already disabled, show info
      SnackbarHelper.showSnackbar(
        title: 'Optimisation désactivée',
        message: 'L\'optimisation de la batterie est déjà désactivée. Les notifications en arrière-plan fonctionnent correctement.',
        backgroundColor: AppColors.success.withOpacity(0.9),
        colorText: AppColors.white,
        duration: const Duration(seconds: 3),
      );
    } else {
      // Request to disable
      final success = await BatteryOptimization.requestIgnoreBatteryOptimizations();
      if (success) {
        // Refresh status
        await _checkBatteryOptimization();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.nightSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white10,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _isChecking ? null : _handleBatteryOptimization,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (_isOptimizationDisabled ? AppColors.success : AppColors.warning)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isOptimizationDisabled ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
                    color: _isOptimizationDisabled ? AppColors.success : AppColors.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'battery_optimization'.tr,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_isChecking)
                        Text(
                          'checking'.tr,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white54,
                          ),
                        )
                      else
                        Text(
                          _isOptimizationDisabled
                              ? 'battery_optimization_disabled'.tr
                              : 'battery_optimization_enabled'.tr,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _isOptimizationDisabled
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isChecking)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                    ),
                  )
                else
                  Icon(
                    _isOptimizationDisabled ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                    color: _isOptimizationDisabled ? AppColors.success : Colors.white30,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget pour afficher les statistiques de l'employé dans le profil
class _EmployeeStatisticsSection extends StatefulWidget {
  final String employeeId;

  const _EmployeeStatisticsSection({required this.employeeId});

  @override
  State<_EmployeeStatisticsSection> createState() => _EmployeeStatisticsSectionState();
}

class _EmployeeStatisticsSectionState extends State<_EmployeeStatisticsSection> {
  final EmployeeStatisticsService _statisticsService = EmployeeStatisticsService();
  EmployeeStatistics? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final stats = await _statisticsService.getEmployeeStatisticsByStringId(widget.employeeId);
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_statistics == null) {
      return const SizedBox.shrink();
    }

    return EmployeeStatisticsWidget(
      statistics: _statistics!,
      isCompact: false,
    );
  }
}
