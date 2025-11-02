import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/helpers/validator.dart';
import '../../components/custom_text_field.dart';
import '../../components/custom_button.dart';

/// Écran d'inscription
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
      return 'Les mots de passe ne correspondent pas';
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
        Get.snackbar(
          'Erreur',
          _authController.errorMessage.value,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('S\'inscrire'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Créer un compte',
                    style: AppTextStyles.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Name field
                  CustomTextField(
                    controller: _nameController,
                    label: 'Nom complet',
                    hint: 'John Doe',
                    validator: Validator.name,
                    prefixIcon: Icons.person_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Email field
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'votre@email.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: Validator.email,
                    prefixIcon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Mot de passe',
                    hint: '••••••••',
                    obscureText: true,
                    validator: Validator.password,
                    prefixIcon: Icons.lock_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Confirm password field
                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirmer le mot de passe',
                    hint: '••••••••',
                    obscureText: true,
                    validator: _confirmPasswordValidator,
                    prefixIcon: Icons.lock_outlined,
                  ),
                  const SizedBox(height: 24),

                  // Register button
                  Obx(
                    () => CustomButton(
                      onPressed: _handleRegister,
                      text: 'S\'inscrire',
                      isLoading: _authController.isLoading.value,
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
}

