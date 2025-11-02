import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/firebase/firebase_init.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'controllers/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Firebase
  try {
    await FirebaseInit.initialize();
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation de Firebase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Lmaalem',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // darkTheme: AppTheme.darkTheme,
      // themeMode: ThemeMode.system,
      
      // Routes
      initialRoute: '/',
      getPages: AppRoutes.getRoutes(),
      
      // Initialiser les controllers globaux
      initialBinding: BindingsBuilder(() {
        Get.put(AuthController());
      }),
    );
  }
}
