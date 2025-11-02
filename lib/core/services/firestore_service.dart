import 'package:cloud_firestore/cloud_firestore.dart';

/// Service pour interagir avec Firestore
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Créer un document
  Future<void> create({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).set(data);
    } catch (e) {
      throw 'Erreur lors de la création: $e';
    }
  }

  /// Lire un document
  Future<Map<String, dynamic>?> read({
    required String collection,
    required String docId,
  }) async {
    try {
      final doc = await _firestore.collection(collection).doc(docId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw 'Erreur lors de la lecture: $e';
    }
  }

  /// Mettre à jour un document
  Future<void> update({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
    } catch (e) {
      throw 'Erreur lors de la mise à jour: $e';
    }
  }

  /// Supprimer un document
  Future<void> delete({
    required String collection,
    required String docId,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
    } catch (e) {
      throw 'Erreur lors de la suppression: $e';
    }
  }

  /// Stream d'un document
  Stream<DocumentSnapshot> streamDocument({
    required String collection,
    required String docId,
  }) {
    return _firestore.collection(collection).doc(docId).snapshots();
  }

  /// Stream d'une collection
  Stream<QuerySnapshot> streamCollection({
    required String collection,
    Query Function(Query)? queryBuilder,
    int? limit,
  }) {
    Query query = _firestore.collection(collection);

    if (queryBuilder != null) {
      query = queryBuilder(query);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }

  /// Lire tous les documents d'une collection
  Future<List<Map<String, dynamic>>> readAll({
    required String collection,
    Query Function(Query)? queryBuilder,
    int? limit,
  }) async {
    try {
      Query query = _firestore.collection(collection);

      if (queryBuilder != null) {
        query = queryBuilder(query);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw 'Erreur lors de la lecture: $e';
    }
  }
}

