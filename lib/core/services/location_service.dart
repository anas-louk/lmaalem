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
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      if (e is LocationException) {
        rethrow;
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
      final address = await getAddressFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
      };
    } catch (e) {
      if (e is LocationException) {
        rethrow;
      }
      throw LocationException('Erreur lors de la récupération de la localisation: $e');
    }
  }
}

