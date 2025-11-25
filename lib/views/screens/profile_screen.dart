import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/categorie_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../components/custom_button.dart';
import '../../components/custom_text_field.dart';
import '../../components/language_switcher.dart';
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
      appBar: AppBar(
        title: Text('profile'.tr),
        actions: const [
          LanguageSwitcher(),
          SizedBox(width: 8),
        ],
      ),
      body: Obx(
        () {
          final user = _authController.currentUser.value;

          if (user == null) {
            return Center(
              child: Text('user_not_connected'.tr),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    user.nomComplet.isNotEmpty ? user.nomComplet[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 48,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                Text(
                  user.nomComplet,
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 8),

                // Type
                Text(
                  '${'user_type'.tr}: ${user.type.toLowerCase() == 'client' ? 'client_type'.tr : 'employee_type'.tr}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                // Localisation
                Text(
                  '${'user_location'.tr}: ${user.localisation}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                // Téléphone
                Text(
                  '${'phone_number'.tr}: ${user.tel}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),

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
                  const Divider(height: 48),
                  _EmployeeStatisticsSection(employeeId: user.id),
                  const Divider(height: 48),
                ],

                // Settings Section
                const Divider(height: 48),
                Text(
                  'settings'.tr,
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Battery Optimization Setting
                _BatteryOptimizationTile(),

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
        builder: (context, setState) => AlertDialog(
          title: Text('become_employee_title'.tr),
          content: SingleChildScrollView(
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
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Annuler'),
            ),
            Obx(
              () => ElevatedButton(
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
                child: authController.isLoading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('confirm'.tr),
              ),
            ),
          ],
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
      builder: (context) => AlertDialog(
        title: Text('become_client_title'.tr),
        content: Text('become_client_message'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          Obx(
            () => ElevatedButton(
              onPressed: authController.isLoading.value
                  ? null
                  : () async {
                      final success = await authController.switchToClient();

                      if (success) {
                        Get.back(); // Close dialog
                        // The redirect will happen automatically via loadUser
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: authController.isLoading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmer'),
            ),
          ),
        ],
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
        builder: (context, setState) => AlertDialog(
          title: Text('update_info_title'.tr),
          content: SingleChildScrollView(
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
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Annuler'),
            ),
            Obx(
              () => ElevatedButton(
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
                child: authController.isLoading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('save'.tr),
              ),
            ),
          ],
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
      builder: (context) => AlertDialog(
        title: Text('delete_account'.tr),
        content: Text('delete_account_confirmation'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          Obx(
            () => ElevatedButton(
              onPressed: authController.isLoading.value
                  ? null
                  : () async {
                      final success = await authController.deleteAccount();
                      if (success && context.mounted) {
                        Get.back(); // Close dialog
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
              ),
              child: authController.isLoading.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('delete'.tr),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: _isChecking ? null : _handleBatteryOptimization,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                _isOptimizationDisabled ? Icons.battery_charging_full : Icons.battery_alert,
                color: _isOptimizationDisabled ? AppColors.success : AppColors.warning,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'battery_optimization'.tr,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_isChecking)
                      Text(
                        'checking'.tr,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
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
                        ),
                      ),
                  ],
                ),
              ),
              if (_isChecking)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  _isOptimizationDisabled ? Icons.check_circle : Icons.arrow_forward_ios,
                  color: _isOptimizationDisabled ? AppColors.success : AppColors.textSecondary,
                  size: 20,
                ),
            ],
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
