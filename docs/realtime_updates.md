# Mises à jour en temps réel - Documentation

## Vue d'ensemble

Le système de mises à jour en temps réel remplace le polling par des streams Firestore pour une expérience utilisateur fluide et réactive.

## Architecture

### Services

#### `RealtimeRequestService`
Service principal pour les mises à jour en temps réel des demandes et employés acceptés.

**Méthodes principales :**
- `listenToRequest(String requestId)` : Écoute une demande spécifique
- `listenToAcceptedEmployeesDirect(String requestId)` : Écoute les employés acceptés pour une demande

**Streams disponibles :**
- `requestStream` : Stream de la demande active
- `employeesStream` : Stream de la liste des employés acceptés
- `connectionStatusStream` : Stream du statut de connexion

#### `RealtimeProvider`
Abstraction pour permettre la bascule entre Firestore streams et WebSocket (futur).

**Implémentations :**
- `FirestoreRealtimeProvider` : Implémentation actuelle avec Firestore
- `WebSocketRealtimeProvider` : Placeholder pour implémentation future

## Utilisation dans le Dashboard Client

### Initialisation du stream

```dart
void _initRealtimeEmployeesStream(String requestId) {
  // Écouter le statut de connexion
  _connectionStatusSubscription = _realtimeService.connectionStatusStream.listen(...);
  
  // Écouter les employés acceptés
  _realtimeService.listenToAcceptedEmployeesDirect(requestId);
  _employeesStreamSubscription = _realtimeService.employeesStream.listen(...);
}
```

### Affichage avec animations

Les employés sont affichés dans une `AnimatedList` pour des animations fluides lors de l'ajout/suppression.

```dart
AnimatedList(
  key: _employeesListKey,
  initialItemCount: employees.length,
  itemBuilder: (context, index, animation) {
    return _buildEmployeeCardAnimated(employee, stats, request, animation);
  },
)
```

## Bascule vers WebSocket

Pour basculer vers WebSocket quand le backend sera prêt :

1. Implémenter `WebSocketRealtimeProvider` dans `realtime_provider.dart`
2. Modifier `RealtimeRequestService` pour utiliser le provider au lieu de Firestore directement
3. Configurer l'URL WebSocket via variables d'environnement

### Exemple d'implémentation WebSocket

```dart
class WebSocketRealtimeProvider implements RealtimeProvider {
  WebSocketChannel? _channel;
  final _dataController = StreamController<dynamic>.broadcast();
  
  @override
  void start() {
    _channel = WebSocketChannel.connect(Uri.parse(websocketUrl));
    _channel!.stream.listen((data) {
      _dataController.add(jsonDecode(data));
    });
  }
  
  @override
  Stream<dynamic> get dataStream => _dataController.stream;
  
  // ... autres méthodes
}
```

## Gestion des erreurs et reconnexion

- Le service détecte automatiquement les pertes de connexion
- Les streams se reconnectent automatiquement quand la connexion est rétablie
- Un indicateur visuel discret (point vert/rouge) informe l'utilisateur du statut

## Performance

- **Pas de polling** : Les mises à jour arrivent instantanément
- **Rebuilds minimaux** : Utilisation de `ValueNotifier` et `ValueListenableBuilder` pour ne mettre à jour que les widgets concernés
- **Animations optimisées** : `AnimatedList` gère les animations de manière performante

## Tests

### Scénarios à tester

1. **Acceptation d'employé** : Un employé accepte → doit apparaître instantanément avec animation
2. **Plusieurs acceptations** : Plusieurs employés acceptent → tous doivent apparaître
3. **Perte de connexion** : Désactiver WiFi → doit afficher indicateur rouge
4. **Reconnexion** : Réactiver WiFi → doit se reconnecter automatiquement
5. **Redémarrage app** : Fermer et rouvrir l'app → doit restaurer l'état

### Checklist de validation

- [ ] Aucun refresh visible de la page
- [ ] Les employés apparaissent avec animation fluide
- [ ] Pas de saut UI lors des mises à jour
- [ ] Indicateur de connexion fonctionne
- [ ] Reconnexion automatique fonctionne
- [ ] Pas d'impact sur la batterie (vérifier avec profiler)

