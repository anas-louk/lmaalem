import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import 'notification_screen.dart';
import 'history_screen.dart';

/// Dashboard Employee with Bottom Navigation
class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  int _currentIndex = 1; // Default to Home (middle)

  final List<Widget> _screens = [
    const NotificationScreen(),
    const _EmployeeHomeScreen(),
    const HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}

/// Home screen content for Employee
class _EmployeeHomeScreen extends StatefulWidget {
  const _EmployeeHomeScreen();

  @override
  State<_EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<_EmployeeHomeScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final MissionController _missionController = Get.put(MissionController());
  final EmployeeController _employeeController = Get.put(EmployeeController());
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMissions();
    });
  }

  Future<void> _loadMissions() async {
    final user = _authController.currentUser.value;
    if (user == null || _loadedUserId == user.id) return;

    try {
      // Get employee document ID from user ID
      final employee = await _employeeController.getEmployeeByUserId(user.id);
      if (employee != null) {
        _loadedUserId = user.id;
        // Load missions using employee document ID
        _missionController.loadMissionsByEmployee(employee.id);
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord Employé'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Get.toNamed(AppRoutes.AppRoutes.profile);
            },
          ),
        ],
      ),
      body: Obx(
        () {
          final user = _authController.currentUser.value;

          if (user == null) {
            return const LoadingWidget();
          }

          // Reload if user changes
          if (_loadedUserId != user.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadMissions();
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Bonjour, ${user.nomComplet}',
                          style: AppTextStyles.h2,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vous êtes connecté en tant qu\'Employé',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),



                // Missions Section
                Text(
                  'Mes Missions Assignées',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 16),

                Obx(
                  () {
                    if (_missionController.isLoading.value) {
                      return const LoadingWidget();
                    }

                    if (_missionController.missions.isEmpty) {
                      return EmptyState(
                        icon: Icons.work_outline,
                        title: 'Aucune mission',
                        message: 'Vous n\'avez pas encore de missions assignées',
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _missionController.missions.length,
                      itemBuilder: (context, index) {
                        final mission = _missionController.missions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('Mission #${mission.id.substring(0, 8)}'),
                            subtitle: Text(
                              'Prix: ${mission.prixMission.toStringAsFixed(2)} €\n'
                              'Statut: ${mission.statutMission}\n'
                              'Date: ${mission.dateStart.toString().substring(0, 10)}',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(mission.statutMission),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                mission.statutMission,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            onTap: () {
                              _missionController.selectMission(mission);
                              Get.toNamed(AppRoutes.AppRoutes.missionDetail);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'in progress':
        return AppColors.info;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

}
