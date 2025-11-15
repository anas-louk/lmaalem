import 'package:flutter/material.dart';
import '../../components/empty_state.dart';

/// Écran de notifications pour les employés
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: const Center(
        child: EmptyState(
          icon: Icons.notifications_none,
          title: 'Aucune notification',
          message: 'Vous n\'avez pas de nouvelles notifications',
        ),
      ),
    );
  }
}

