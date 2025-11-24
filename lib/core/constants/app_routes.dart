/// Constantes pour les routes de l'application
class AppRoutes {
  AppRoutes._(); // Private constructor

  // Auth Routes
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Dashboard Routes
  static const String clientDashboard = '/client-dashboard';
  static const String employeeDashboard = '/employee-dashboard';

  // Main Routes
  static const String home = '/home';
  static const String profile = '/profile';
  static const String settings = '/settings';

  // Employee Routes
  static const String employees = '/employees';
  static const String employeeDetail = '/employee-detail';
  static const String employeeRegister = '/employee-register';

  // Mission Routes
  static const String missions = '/missions';
  static const String missionDetail = '/mission-detail';
  static const String addMission = '/add-mission';

  // Category Routes
  static const String categories = '/categories';

  // Request Routes
  static const String requestSubmission = '/request-submission';
  static const String requestDetail = '/request-detail';

  // Navigation Routes
  static const String notifications = '/notifications';
  static const String history = '/history';
  static const String chat = '/chat';

  // Call Routes
  static const String incomingCall = '/incoming-call';
  static const String call = '/call';
}
