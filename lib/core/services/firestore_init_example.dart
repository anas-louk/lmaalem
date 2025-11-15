import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/user_model.dart';
import '../../data/models/categorie_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/client_model.dart';
import '../../data/models/mission_model.dart';

/// Example service to initialize Firestore database with sample data
/// 
/// This file demonstrates how to create collections and add sample records
/// for each entity in the database structure.
/// 
/// Usage:
/// ```dart
/// final initService = FirestoreInitExample();
/// await initService.initializeDatabase();
/// ```
class FirestoreInitExample {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize the database with sample records for all collections
  Future<void> initializeDatabase() async {
    try {
      print('🚀 Starting database initialization...');

      // 1. Create sample User
      final user = await _createSampleUser();
      print('✅ Created User: ${user.id}');

      // 2. Create sample Categorie
      final categorie = await _createSampleCategorie();
      print('✅ Created Categorie: ${categorie.id}');

      // 3. Create sample Employee (references User and Categorie)
      final employee = await _createSampleEmployee(
        userId: user.id,
        categorieId: categorie.id,
      );
      print('✅ Created Employee: ${employee.id}');

      // 4. Create sample Client (references User)
      final client = await _createSampleClient(userId: user.id);
      print('✅ Created Client: ${client.id}');

      // 5. Create sample Mission (references Employee and Client)
      final mission = await _createSampleMission(
        employeeId: employee.id,
        clientId: client.id,
      );
      print('✅ Created Mission: ${mission.id}');

      print('🎉 Database initialization completed successfully!');
    } catch (e) {
      print('❌ Error initializing database: $e');
      rethrow;
    }
  }

  /// Create a sample User document
  Future<UserModel> _createSampleUser() async {
    final now = DateTime.now();
    final user = UserModel(
      id: 'user_001', // In production, use auto-generated ID
      nomComplet: 'Ahmed Benali',
      localisation: 'Casablanca, Maroc',
      type: 'Employee',
      tel: '+212612345678',
      createdAt: now,
      updatedAt: now,
    );

    // Create document in Firestore
    await _firestore
        .collection('users')
        .doc(user.id)
        .set(user.toMap());

    return user;
  }

  /// Create a sample Categorie document
  Future<CategorieModel> _createSampleCategorie() async {
    final now = DateTime.now();
    final categorie = CategorieModel(
      id: 'cat_001', // In production, use auto-generated ID
      nom: 'Plombier',
      createdAt: now,
      updatedAt: now,
    );

    // Create document in Firestore
    await _firestore
        .collection('categories')
        .doc(categorie.id)
        .set(categorie.toMap());

    return categorie;
  }

  /// Create a sample Employee document
  Future<EmployeeModel> _createSampleEmployee({
    required String userId,
    required String categorieId,
  }) async {
    final now = DateTime.now();
    final employee = EmployeeModel(
      id: 'emp_001', // In production, use auto-generated ID
      nomComplet: 'Ahmed Benali',
      localisation: 'Casablanca, Maroc',
      tel: '+212612345678',
      createdAt: now,
      updatedAt: now,
      image: 'https://example.com/images/ahmed.jpg',
      categorieId: categorieId,
      ville: 'Casablanca',
      disponibilite: true,
      competence: 'Installation et réparation de plomberie',
      bio: 'Plombier expérimenté avec 10 ans d\'expérience',
      gallery: 'https://example.com/galleries/ahmed',
      userId: userId,
    );

    // Create document in Firestore using toMapWithIds() to store string IDs
    // Alternatively, use toMap() to store DocumentReference objects
    await _firestore
        .collection('employees')
        .doc(employee.id)
        .set(employee.toMapWithIds());

    return employee;
  }

  /// Create a sample Client document
  Future<ClientModel> _createSampleClient({required String userId}) async {
    final now = DateTime.now();
    final client = ClientModel(
      id: 'cli_001', // In production, use auto-generated ID
      nomComplet: 'Fatima Alami',
      localisation: 'Rabat, Maroc',
      tel: '+212698765432',
      createdAt: now,
      updatedAt: now,
      userId: userId,
    );

    // Create document in Firestore using toMapWithIds() to store string IDs
    // Alternatively, use toMap() to store DocumentReference objects
    await _firestore
        .collection('clients')
        .doc(client.id)
        .set(client.toMapWithIds());

    return client;
  }

  /// Create a sample Mission document
  Future<MissionModel> _createSampleMission({
    required String employeeId,
    required String clientId,
  }) async {
    final now = DateTime.now();
    final mission = MissionModel(
      id: 'mis_001', // In production, use auto-generated ID
      prixMission: 500.00,
      dateStart: DateTime(2024, 2, 1, 8, 0),
      dateEnd: DateTime(2024, 2, 1, 17, 0),
      objMission: 'Réparation de fuite d\'eau dans la salle de bain',
      statutMission: 'Pending',
      commentaire: 'Urgent - besoin d\'intervention rapide',
      rating: null,
      employeeId: employeeId,
      clientId: clientId,
      createdAt: now,
      updatedAt: now,
    );

    // Create document in Firestore using toMapWithIds() to store string IDs
    // Alternatively, use toMap() to store DocumentReference objects
    await _firestore
        .collection('missions')
        .doc(mission.id)
        .set(mission.toMapWithIds());

    return mission;
  }

  /// Alternative: Create documents with auto-generated IDs
  /// This is the recommended approach for production
  Future<void> createWithAutoGeneratedIds() async {
    try {
      print('🚀 Creating documents with auto-generated IDs...');

      // 1. Create User with auto-generated ID
      final userRef = _firestore.collection('users').doc();
      final user = UserModel(
        id: userRef.id,
        nomComplet: 'Ahmed Benali',
        localisation: 'Casablanca, Maroc',
        type: 'Employee',
        tel: '+212612345678',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await userRef.set(user.toMap());
      print('✅ Created User: ${user.id}');

      // 2. Create Categorie with auto-generated ID
      final categorieRef = _firestore.collection('categories').doc();
      final categorie = CategorieModel(
        id: categorieRef.id,
        nom: 'Plombier',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await categorieRef.set(categorie.toMap());
      print('✅ Created Categorie: ${categorie.id}');

      // 3. Create Employee with auto-generated ID
      final employeeRef = _firestore.collection('employees').doc();
      final employee = EmployeeModel(
        id: employeeRef.id,
        nomComplet: 'Ahmed Benali',
        localisation: 'Casablanca, Maroc',
        tel: '+212612345678',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        categorieId: categorie.id,
        ville: 'Casablanca',
        disponibilite: true,
        competence: 'Installation et réparation de plomberie',
        bio: 'Plombier expérimenté avec 10 ans d\'expérience',
        userId: user.id,
      );
      await employeeRef.set(employee.toMapWithIds());
      print('✅ Created Employee: ${employee.id}');

      // 4. Create Client with auto-generated ID
      final clientRef = _firestore.collection('clients').doc();
      final clientUser = UserModel(
        id: _firestore.collection('users').doc().id,
        nomComplet: 'Fatima Alami',
        localisation: 'Rabat, Maroc',
        type: 'Client',
        tel: '+212698765432',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(clientUser.id).set(clientUser.toMap());

      final client = ClientModel(
        id: clientRef.id,
        nomComplet: 'Fatima Alami',
        localisation: 'Rabat, Maroc',
        tel: '+212698765432',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: clientUser.id,
      );
      await clientRef.set(client.toMapWithIds());
      print('✅ Created Client: ${client.id}');

      // 5. Create Mission with auto-generated ID
      final missionRef = _firestore.collection('missions').doc();
      final mission = MissionModel(
        id: missionRef.id,
        prixMission: 500.00,
        dateStart: DateTime(2024, 2, 1, 8, 0),
        dateEnd: DateTime(2024, 2, 1, 17, 0),
        objMission: 'Réparation de fuite d\'eau dans la salle de bain',
        statutMission: 'Pending',
        commentaire: 'Urgent - besoin d\'intervention rapide',
        employeeId: employee.id,
        clientId: client.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await missionRef.set(mission.toMapWithIds());
      print('✅ Created Mission: ${mission.id}');

      print('🎉 All documents created with auto-generated IDs!');
    } catch (e) {
      print('❌ Error creating documents: $e');
      rethrow;
    }
  }

  /// Example: Create multiple sample records for testing
  Future<void> createMultipleSamples() async {
    try {
      print('🚀 Creating multiple sample records...');

      // Create multiple categories
      final categories = ['Plombier', 'Électricien', 'Menuisier', 'Peintre'];
      final categoryIds = <String>[];

      for (var nom in categories) {
        final ref = _firestore.collection('categories').doc();
        final categorie = CategorieModel(
          id: ref.id,
          nom: nom,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await ref.set(categorie.toMap());
        categoryIds.add(categorie.id);
        print('✅ Created Categorie: $nom (${categorie.id})');
      }

      // Create multiple users and employees
      final employeesData = [
        {
          'nomComplet': 'Ahmed Benali',
          'tel': '+212612345678',
          'localisation': 'Casablanca, Maroc',
          'ville': 'Casablanca',
          'competence': 'Installation et réparation de plomberie',
          'categorieIndex': 0, // Plombier
        },
        {
          'nomComplet': 'Hassan Amrani',
          'tel': '+212612345679',
          'localisation': 'Rabat, Maroc',
          'ville': 'Rabat',
          'competence': 'Installation électrique et dépannage',
          'categorieIndex': 1, // Électricien
        },
      ];

      for (var empData in employeesData) {
        // Create user
        final userRef = _firestore.collection('users').doc();
        final user = UserModel(
          id: userRef.id,
          nomComplet: empData['nomComplet'] as String,
          localisation: empData['localisation'] as String,
          type: 'Employee',
          tel: empData['tel'] as String,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await userRef.set(user.toMap());

        // Create employee
        final empRef = _firestore.collection('employees').doc();
        final employee = EmployeeModel(
          id: empRef.id,
          nomComplet: empData['nomComplet'] as String,
          localisation: empData['localisation'] as String,
          tel: empData['tel'] as String,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          categorieId: categoryIds[empData['categorieIndex'] as int],
          ville: empData['ville'] as String,
          disponibilite: true,
          competence: empData['competence'] as String,
          userId: user.id,
        );
        await empRef.set(employee.toMapWithIds());
        print('✅ Created Employee: ${employee.nomComplet} (${employee.id})');
      }

      print('🎉 Multiple sample records created successfully!');
    } catch (e) {
      print('❌ Error creating multiple samples: $e');
      rethrow;
    }
  }
}

/// Example usage in your app:
/// 
/// ```dart
/// // In your main.dart or initialization code:
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp();
///   
///   // Initialize database with sample data (only for development/testing)
///   if (kDebugMode) {
///     final initService = FirestoreInitExample();
///     await initService.initializeDatabase();
///     // Or use: await initService.createWithAutoGeneratedIds();
///     // Or use: await initService.createMultipleSamples();
///   }
///   
///   runApp(MyApp());
/// }
/// ```

