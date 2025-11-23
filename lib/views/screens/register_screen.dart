import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/helpers/validator.dart';
import '../../core/helpers/snackbar_helper.dart';
import '../../components/custom_text_field.dart';
import '../../components/custom_button.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;

/// Écran d'inscription avec le même design que la page de connexion
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _confirmPasswordValidator(String? value) {
    if (value != _passwordController.text) {
      return 'passwords_dont_match'.tr;
    }
    return null;
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );

      if (!success) {
        SnackbarHelper.showError(_authController.errorMessage.value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double maxWidth = 420;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBrandBadge(),
                      const SizedBox(height: 24),
                      _buildRegisterCard(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandBadge() {
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          'app_name'.tr,
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildRegisterCard() {
    return Form(
      key: _formKey,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.nightSurface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'create_account'.tr,
              style: AppTextStyles.h2.copyWith(
                color: Colors.white,
                fontSize: 23,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'create_account_subtitle'.tr,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _nameController,
              label: 'full_name'.tr,
              hint: 'name_hint'.tr,
              validator: Validator.name,
              prefixIcon: Icons.person_outline,
              fillColor: AppColors.nightSecondary,
              textColor: Colors.white,
              labelColor: Colors.white,
              hintColor: Colors.white54,
              iconColor: Colors.white70,
              borderColor: Colors.white10,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _emailController,
              label: 'email'.tr,
              hint: 'email_hint'.tr,
              keyboardType: TextInputType.emailAddress,
              validator: Validator.email,
              prefixIcon: Icons.email_outlined,
              fillColor: AppColors.nightSecondary,
              textColor: Colors.white,
              labelColor: Colors.white,
              hintColor: Colors.white54,
              iconColor: Colors.white70,
              borderColor: Colors.white10,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _passwordController,
              label: 'password'.tr,
              hint: 'password_hint'.tr,
              obscureText: !_showPassword,
              validator: Validator.password,
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: _showPassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              onSuffixTap: () => setState(() => _showPassword = !_showPassword),
              fillColor: AppColors.nightSecondary,
              textColor: Colors.white,
              labelColor: Colors.white,
              hintColor: Colors.white54,
              iconColor: Colors.white70,
              borderColor: Colors.white10,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _confirmPasswordController,
              label: 'confirm_password'.tr,
              hint: 'password_hint'.tr,
              obscureText: !_showConfirmPassword,
              validator: _confirmPasswordValidator,
              prefixIcon: Icons.lock_outline,
              suffixIcon: _showConfirmPassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              onSuffixTap: () => setState(
                () => _showConfirmPassword = !_showConfirmPassword,
              ),
              fillColor: AppColors.nightSecondary,
              textColor: Colors.white,
              labelColor: Colors.white,
              hintColor: Colors.white54,
              iconColor: Colors.white70,
              borderColor: Colors.white10,
            ),
            const SizedBox(height: 16),
            Obx(
              () => CustomButton(
                onPressed: _authController.isLoading.value ? null : _handleRegister,
                text: 'sign_up'.tr,
                isLoading: _authController.isLoading.value,
                height: 50,
              ),
            ),
            const SizedBox(height: 12),
            _buildLoginRedirect(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginRedirect() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'already_have_account'.tr,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
        TextButton(
          onPressed: () => Get.offAllNamed(AppRoutes.AppRoutes.login),
          child: Text(
            'sign_in'.tr,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
        ),
      ],
    );
  }
}

