import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';

/// Exception personnalisée pour les erreurs de localisation
class LocationException implements Exception {
  final String message;
  final bool canOpenSettings;
  
  LocationException(this.message, {this.canOpenSettings = false});
  
  @override
  String toString() => message;
}

/// Service pour gérer la localisation
class LocationService {
  /// Vérifier si les services de localisation sont activés
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  /// Ouvrir les paramètres de localisation
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
  
  /// Ouvrir les paramètres de l'application pour les permissions
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Vérifier et demander les permissions de localisation
  Future<bool> requestLocationPermission() async {
    // Vérifier si les services de localisation sont activés
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        'location_gps_disabled'.tr,
        canOpenSettings: true,
      );
    }

    // Vérifier les permissions
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException(
          'location_permission_denied'.tr,
          canOpenSettings: true,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'location_permission_denied_forever'.tr,
        canOpenSettings: true,
      );
    }

    return true;
  }

  /// Obtenir la position actuelle
  Future<Position> getCurrentPosition() async {
    await requestLocationPermission();
    
    try {
      // Essayer d'abord avec une haute précision
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10), // Timeout de 10 secondes
        ).timeout(
          const Duration(seconds: 12), // Timeout global de 12 secondes
        );
      } catch (e) {
        // Si la haute précision échoue ou timeout, essayer avec une précision moyenne
        if (e is TimeoutException || e.toString().contains('timeout')) {
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 8), // Timeout de 8 secondes
          ).timeout(
            const Duration(seconds: 10), // Timeout global de 10 secondes
          );
        }
        rethrow;
      }
    } catch (e) {
      if (e is LocationException) {
        rethrow;
      }
      if (e is TimeoutException) {
        throw LocationException(
          'Le GPS prend trop de temps à répondre. Veuillez vérifier que le GPS est activé et réessayer.',
        );
      }
      throw LocationException('Erreur lors de la récupération de la position: $e');
    }
  }

  /// Obtenir l'adresse à partir des coordonnées
  Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(
        const Duration(seconds: 10), // Timeout pour la géocodification
        onTimeout: () => <Placemark>[], // Retourner une liste vide en cas de timeout
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '';
        
        if (place.street != null && place.street!.isNotEmpty) {
          address += place.street!;
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.subLocality!;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.locality!;
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.administrativeArea!;
        }
        if (place.country != null && place.country!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.country!;
        }

        return address.isNotEmpty ? address : 'Localisation inconnue';
      }

      return 'Localisation inconnue';
    } catch (e) {
      throw 'Erreur lors de la récupération de l\'adresse: $e';
    }
  }

  /// Obtenir la position actuelle avec l'adresse
  Future<Map<String, dynamic>> getCurrentLocationWithAddress() async {
    try {
      final position = await getCurrentPosition();
      
      // Essayer de récupérer l'adresse, mais ne pas bloquer si ça échoue
      String address = 'Localisation inconnue';
      try {
        address = await getAddressFromCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (e) {
        // Si la géocodification échoue, on continue avec l'adresse par défaut
        // mais on garde les coordonnées
        print('Erreur lors de la géocodification: $e');
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
      };
    } catch (e) {
      if (e is LocationException) {
        rethrow;
      }
      if (e is TimeoutException) {
        throw LocationException(
          'Timeout lors de la récupération de la localisation. Veuillez vérifier que le GPS est activé et réessayer.',
        );
      }
      throw LocationException('Erreur lors de la récupération de la localisation: $e');
    }
  }
}

