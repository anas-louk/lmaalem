import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../core/helpers/validator.dart';
import '../../components/custom_text_field.dart';
import '../../components/custom_button.dart';

/// Écran de connexion
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!success) {
        Get.snackbar(
          'error'.tr,
          _authController.errorMessage.value,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.white,
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final success = await _authController.signInWithGoogle();

    if (!success && _authController.errorMessage.value.isNotEmpty) {
      Get.snackbar(
        'error'.tr,
        _authController.errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Titre
                  Icon(
                    Icons.work_outline,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'welcome'.tr,
                    style: AppTextStyles.h1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'connect_to_account'.tr,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Google Sign-In Button
                  Obx(
                    () => CustomButton(
                      onPressed: _authController.isLoading.value
                          ? null
                          : _handleGoogleSignIn,
                      text: 'continue_with_google'.tr,
                      isLoading: _authController.isLoading.value,
                      backgroundColor: AppColors.white,
                      textColor: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.grey)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or'.tr,
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.grey)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Email field
                  CustomTextField(
                    controller: _emailController,
                    label: 'email'.tr,
                    hint: 'email_hint'.tr,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validator.email,
                    prefixIcon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  CustomTextField(
                    controller: _passwordController,
                    label: 'password'.tr,
                    hint: 'password_hint'.tr,
                    obscureText: true,
                    validator: Validator.password,
                    prefixIcon: Icons.lock_outlined,
                  ),
                  const SizedBox(height: 8),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Get.toNamed(AppRoutes.AppRoutes.forgotPassword);
                      },
                      child: Text('forgot_password_question'.tr),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  Obx(
                    () => CustomButton(
                      onPressed: _authController.isLoading.value
                          ? null
                          : _handleLogin,
                      text: 'sign_in'.tr,
                      isLoading: _authController.isLoading.value,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'no_account'.tr,
                        style: AppTextStyles.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          Get.toNamed(AppRoutes.AppRoutes.register);
                        },
                        child: Text('sign_up'.tr),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
