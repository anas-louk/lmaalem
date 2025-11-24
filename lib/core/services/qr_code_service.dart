import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/logger.dart';

/// Service pour gérer les tokens QR code pour la confirmation de fin de demande
class QRCodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Génère un token unique pour une demande
  String _generateToken() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999);
    return '${timestamp}_$randomPart';
  }
  
  /// Crée un token QR code pour une demande et le stocke dans Firestore
  /// Retourne le token généré
  Future<String> createFinishToken({
    required String requestId,
    required String clientId,
    required String employeeId,
    required double price,
    double? rating,
    String? comment,
  }) async {
    try {
      final token = _generateToken();
      final expiresAt = DateTime.now().add(const Duration(hours: 24)); // Token valide 24h
      
      await _firestore.collection('request_finish_tokens').doc(token).set({
        'requestId': requestId,
        'clientId': clientId,
        'employeeId': employeeId,
        'price': price,
        'rating': rating,
        'comment': comment,
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'used': false,
        'usedAt': null,
      });
      
      Logger.logInfo('QRCodeService.createFinishToken', 'Token created: $token for request: $requestId');
      return token;
    } catch (e, stackTrace) {
      Logger.logError('QRCodeService.createFinishToken', e, stackTrace);
      rethrow;
    }
  }
  
  /// Valide et utilise un token QR code
  /// Retourne les données de la demande si le token est valide
  Future<Map<String, dynamic>?> validateAndUseToken({
    required String token,
    required String employeeId,
  }) async {
    try {
      final doc = await _firestore.collection('request_finish_tokens').doc(token).get();
      
      if (!doc.exists) {
        Logger.logInfo('QRCodeService.validateAndUseToken', 'Token not found: $token');
        return null;
      }
      
      final data = doc.data()!;
      
      // Vérifier si le token a déjà été utilisé
      if (data['used'] == true) {
        Logger.logInfo('QRCodeService.validateAndUseToken', 'Token already used: $token');
        return null;
      }
      
      // Vérifier si le token a expiré
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        Logger.logInfo('QRCodeService.validateAndUseToken', 'Token expired: $token');
        return null;
      }
      
      // Vérifier que l'employé correspond
      if (data['employeeId'] != employeeId) {
        Logger.logInfo('QRCodeService.validateAndUseToken', 'Employee mismatch: expected ${data['employeeId']}, got $employeeId');
        return null;
      }
      
      // Marquer le token comme utilisé
      await _firestore.collection('request_finish_tokens').doc(token).update({
        'used': true,
        'usedAt': FieldValue.serverTimestamp(),
      });
      
      Logger.logInfo('QRCodeService.validateAndUseToken', 'Token validated and used: $token');
      
      return {
        'requestId': data['requestId'] as String,
        'clientId': data['clientId'] as String,
        'employeeId': data['employeeId'] as String,
        'price': data['price'] as double,
        'rating': data['rating'] as double?,
        'comment': data['comment'] as String?,
      };
    } catch (e, stackTrace) {
      Logger.logError('QRCodeService.validateAndUseToken', e, stackTrace);
      return null;
    }
  }
  
  /// Supprime un token (pour nettoyage)
  Future<void> deleteToken(String token) async {
    try {
      await _firestore.collection('request_finish_tokens').doc(token).delete();
    } catch (e, stackTrace) {
      Logger.logError('QRCodeService.deleteToken', e, stackTrace);
    }
  }
}

