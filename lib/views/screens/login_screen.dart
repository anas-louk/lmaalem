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
      backgroundColor: Theme.of(context).colorScheme.background,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            'app_name'.tr,
            style: AppTextStyles.h3.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(colorScheme.brightness == Brightness.dark ? 0.4 : 0.1),
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
                color: colorScheme.onSurface,
                fontSize: 23,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'connect_to_account'.tr,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
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
              fillColor: colorScheme.surfaceVariant,
              textColor: colorScheme.onSurface,
              labelColor: colorScheme.onSurface,
              hintColor: colorScheme.onSurfaceVariant,
              iconColor: colorScheme.onSurfaceVariant,
              borderColor: colorScheme.outline.withOpacity(0.2),
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
              fillColor: colorScheme.surfaceVariant,
              textColor: colorScheme.onSurface,
              labelColor: colorScheme.onSurface,
              hintColor: colorScheme.onSurfaceVariant,
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
                    color: Theme.of(context).colorScheme.onSurface,
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
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or'.tr,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
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
