import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../core/constants/app_colors.dart';

/// Écran de démarrage (Splash Screen)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthController _authController = Get.put(AuthController());

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));

    final user = _authController.currentUser.value;
    if (user != null) {
      // Rediriger selon le type d'utilisateur
      if (user.type.toLowerCase() == 'employee') {
        Get.offAllNamed(AppRoutes.AppRoutes.employeeDashboard);
      } else {
        Get.offAllNamed(AppRoutes.AppRoutes.clientDashboard);
      }
    } else {
      Get.offAllNamed(AppRoutes.AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo ou icône
            Icon(
              Icons.shopping_bag,
              size: 100,
              color: AppColors.white,
            ),
            const SizedBox(height: 24),
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'Chargement...',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

