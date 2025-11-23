import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../core/helpers/validator.dart';
import '../../core/helpers/snackbar_helper.dart';
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
  bool _showPassword = false;

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
        SnackbarHelper.showError(
          _authController.errorMessage.value,
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final success = await _authController.signInWithGoogle();

    if (!success && _authController.errorMessage.value.isNotEmpty) {
      SnackbarHelper.showError(_authController.errorMessage.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = 420;
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
                      _buildLoginCard(context),
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
    return Align(
      alignment: Alignment.center,
      child: Container(
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
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
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
              'welcome_back'.tr,
              style: AppTextStyles.h2.copyWith(
                color: Colors.white,
                fontSize: 23,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'connect_to_account'.tr,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            _buildSocialButtons(),
            const SizedBox(height: 14),
            _buildDivider(),
            const SizedBox(height: 14),
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
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.toNamed(AppRoutes.AppRoutes.forgotPassword),
                child: Text(
                  'forgot_password_question'.tr,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => CustomButton(
                onPressed: _authController.isLoading.value ? null : _handleLogin,
                text: 'sign_in'.tr,
                isLoading: _authController.isLoading.value,
                height: 50,
              ),
            ),
            const SizedBox(height: 10),
            _buildRegisterRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        _SocialButton(
          icon: Icons.apple,
          label: 'login_with_apple'.tr,
          onTap: () {},
        ),
        const SizedBox(height: 12),
        Obx(
          () => _SocialButton(
            icon: Icons.g_translate,
            label: 'continue_with_google'.tr,
            onTap: _authController.isLoading.value ? null : _handleGoogleSignIn,
            isLoading: _authController.isLoading.value,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white12,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or'.tr,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white54,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white12,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'no_account'.tr,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
        TextButton(
          onPressed: () => Get.toNamed(AppRoutes.AppRoutes.register),
          child: Text(
            'sign_up'.tr,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _SocialButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null || isLoading;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: disabled ? 0.5 : 1,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
