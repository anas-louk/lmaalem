# Checklist de Tests - Mises à jour en temps réel

## Scénarios de test

### ✅ Test 1 : Acceptation d'un employé
- [ ] Créer une demande en tant que client
- [ ] Un employé accepte la demande
- [ ] L'employé apparaît **instantanément** dans la liste (pas de refresh visible)
- [ ] Animation fluide lors de l'apparition (slide + fade)
- [ ] Pas de saut UI ou de rebuild complet de la page

### ✅ Test 2 : Acceptations multiples
- [ ] Créer une demande
- [ ] Plusieurs employés acceptent successivement
- [ ] Chaque employé apparaît avec animation
- [ ] La liste se met à jour sans refresh visible
- [ ] Tous les employés restent visibles

### ✅ Test 3 : Perte de connexion
- [ ] Créer une demande
- [ ] Désactiver WiFi/Données mobiles
- [ ] L'indicateur de connexion passe au rouge
- [ ] Un message discret informe l'utilisateur
- [ ] Les données existantes restent affichées

### ✅ Test 4 : Reconnexion
- [ ] Après perte de connexion (test 3)
- [ ] Réactiver WiFi/Données
- [ ] L'indicateur redevient vert
- [ ] Message de reconnexion
- [ ] Les nouvelles données arrivent automatiquement

### ✅ Test 5 : Redémarrage de l'app
- [ ] Créer une demande avec des employés acceptés
- [ ] Fermer complètement l'app
- [ ] Rouvrir l'app
- [ ] L'état est restauré (demande + employés)
- [ ] Le stream se reconnecte automatiquement

### ✅ Test 6 : Annulation de demande
- [ ] Créer une demande avec des employés acceptés
- [ ] Annuler la demande
- [ ] Le formulaire réapparaît
- [ ] Les streams sont correctement arrêtés
- [ ] Pas de fuite mémoire

### ✅ Test 7 : Performance
- [ ] Surveiller le CPU (DevTools Profiler)
- [ ] Pas de polling actif (vérifier les logs)
- [ ] Consommation batterie normale
- [ ] Pas de rebuilds inutiles (vérifier avec Flutter Inspector)

## Critères de validation

### Performance
- ✅ Aucun `Timer.periodic` ou polling visible dans les logs
- ✅ Streams Firestore actifs uniquement quand nécessaire
- ✅ Rebuilds minimaux (seulement les widgets concernés)

### UX
- ✅ Aucun refresh visible de la page
- ✅ Animations fluides (300ms max)
- ✅ Indicateur de connexion discret mais visible
- ✅ Pas de saut UI lors des mises à jour

### Stabilité
- ✅ Pas de fuite mémoire (vérifier avec DevTools)
- ✅ Streams correctement annulés dans dispose()
- ✅ Gestion d'erreurs robuste
- ✅ Reconnexion automatique fonctionnelle

## Commandes de test

```bash
# Vérifier les logs de stream
adb logcat | grep -i "realtime\|stream\|firestore"

# Profiler les performances
flutter run --profile

# Vérifier les fuites mémoire
flutter run --profile
# Puis utiliser DevTools Memory tab
```

