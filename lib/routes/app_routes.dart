import 'package:get/get.dart';
import '../views/screens/splash_screen.dart';
import '../views/screens/login_screen.dart';
import '../views/screens/register_screen.dart';
import '../views/screens/home_screen.dart';
import '../views/screens/profile_screen.dart';
import '../views/screens/client_dashboard_screen.dart';
import '../views/screens/employee_dashboard_screen.dart';
import '../views/screens/notification_screen.dart';
import '../views/screens/history_screen.dart';
import '../views/screens/categories_screen.dart';
import '../views/screens/request_submission_screen.dart';
import '../core/constants/app_routes.dart' as route_constants;

/// Gestionnaire de routes de l'application
class AppRoutes {
  AppRoutes._(); // Private constructor

  /// Liste des routes de l'application
  static List<GetPage> getRoutes() {
    return [
      GetPage(
        name: route_constants.AppRoutes.splash,
        page: () => const SplashScreen(),
      ),
      GetPage(
        name: route_constants.AppRoutes.login,
        page: () => const LoginScreen(),
      ),
      GetPage(
        name: route_constants.AppRoutes.register,
        page: () => const RegisterScreen(),
      ),
      GetPage(
        name: route_constants.AppRoutes.clientDashboard,
        page: () => const ClientDashboardScreen(),
      ),
      GetPage(
        name: route_constants.AppRoutes.employeeDashboard,
        page: () => const EmployeeDashboardScreen(),
      ),
      GetPage(
        name: route_constants.AppRoutes.home,
        page: () => const HomeScreen(),
      ),
      GetPage(
        name: route_constants.AppRoutes.profile,
        page: () => const ProfileScreen(),
      ),
      GetPage(
        name: route_constants.AppRoutes.notifications,
        page: () => const NotificationScreen(),
      ),
      GetPage(
        name: route_constants.AppRoutes.history,
        page: () => const HistoryScreen(),
      ),
      GetPage(
        name: route_constants.AppRoutes.categories,
        page: () => const CategoriesScreen(),
      ),
      GetPage(
        name: route_constants.AppRoutes.requestSubmission,
        page: () {
          final categorieId = Get.arguments as String?;
          if (categorieId == null) {
            Get.back();
            return const CategoriesScreen();
          }
          return RequestSubmissionScreen(categorieId: categorieId);
        },
      ),
      // Ajouter d'autres routes ici
    ];
  }
}

