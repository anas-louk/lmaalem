import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';

/// Service pour interagir avec Firebase Storage
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploader un fichier
  Future<String> uploadFile({
    required String path,
    required File file,
    String? fileName,
  }) async {
    try {
      final ref = _storage.ref(path).child(fileName ?? file.path.split('/').last);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      throw 'Erreur lors de l\'upload: $e';
    }
  }

  /// Uploader des bytes
  Future<String> uploadBytes({
    required String path,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final ref = _storage.ref(path).child(fileName);
      await ref.putData(Uint8List.fromList(bytes));
      return await ref.getDownloadURL();
    } catch (e) {
      throw 'Erreur lors de l\'upload: $e';
    }
  }

  /// Télécharger une URL
  Future<String> getDownloadURL(String path) async {
    try {
      return await _storage.ref(path).getDownloadURL();
    } catch (e) {
      throw 'Erreur lors du téléchargement: $e';
    }
  }

  /// Supprimer un fichier
  Future<void> deleteFile(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (e) {
      throw 'Erreur lors de la suppression: $e';
    }
  }

  /// Uploader une image de profil
  Future<String> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final fileName = 'profile_$userId.jpg';
      return await uploadFile(
        path: 'profiles/$userId',
        file: imageFile,
        fileName: fileName,
      );
    } catch (e) {
      throw 'Erreur lors de l\'upload de l\'image de profil: $e';
    }
  }
}

