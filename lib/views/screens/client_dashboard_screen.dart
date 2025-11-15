import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/mission_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart' as AppRoutes;
import '../../components/loading_widget.dart';
import '../../components/empty_state.dart';
import 'history_screen.dart';
import 'categories_screen.dart';

/// Dashboard Client with Bottom Navigation
class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  int _currentIndex = 1; // Default to Home (middle)

  final List<Widget> _screens = [
    const HistoryScreen(),
    const _ClientHomeScreen(),
    const CategoriesScreen(),
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
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_outlined),
            activeIcon: Icon(Icons.category),
            label: 'Catégories',
          ),
        ],
      ),
    );
  }
}

/// Home screen content for Client
class _ClientHomeScreen extends StatefulWidget {
  const _ClientHomeScreen();

  @override
  State<_ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<_ClientHomeScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final MissionController _missionController = Get.put(MissionController());
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMissions();
    });
  }

  void _loadMissions() {
    final user = _authController.currentUser.value;
    if (user != null && _loadedUserId != user.id) {
      _missionController.loadMissionsByClient(user.id);
      _loadedUserId = user.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord Client'),
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
                          'Vous êtes connecté en tant que Client',
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
                  'Mes Missions',
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
                        message: 'Vous n\'avez pas encore de missions',
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
                              'Statut: ${mission.statutMission}',
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: AppColors.primary,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.toNamed(AppRoutes.AppRoutes.addMission);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

}
