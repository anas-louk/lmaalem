# Scripts d'initialisation

## Initialisation des catégories

Le script `init_categories.dart` permet d'ajouter 5 catégories par défaut dans Firestore.

### Catégories créées :
1. **Plombier**
2. **Électricien**
3. **Peintre**
4. **Menuisier**
5. **Nettoyage**

### Comment utiliser :

#### Méthode 1 : Depuis main.dart (recommandé)

1. Ouvrez `lib/main.dart`
2. Décommentez l'import :
   ```dart
   import 'core/scripts/init_categories.dart';
   ```
3. Décommentez l'appel dans la fonction `main()` :
   ```dart
   try {
     await InitCategories.run();
   } catch (e) {
     debugPrint('Erreur lors de l\'initialisation des catégories: $e');
   }
   ```
4. Lancez l'application une fois
5. Re-commentez les lignes pour éviter de réexécuter le script

#### Méthode 2 : Depuis n'importe où dans l'application

```dart
import 'package:lmaalem/core/scripts/init_categories.dart';

// Dans votre code
await InitCategories.run();
```

### Notes importantes :

- Le script vérifie automatiquement si les catégories existent déjà avant de les créer
- Les catégories existantes seront ignorées (pas de doublons)
- Le script affiche un résumé dans la console avec le nombre de catégories créées
- Une fois les catégories créées, vous pouvez re-commenter le code pour éviter de réexécuter le script

