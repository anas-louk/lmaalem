import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Service pour gérer la localisation
class LocationService {
  /// Vérifier et demander les permissions de localisation
  Future<bool> requestLocationPermission() async {
    try {
      // Vérifier si les services de localisation sont activés
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Les services de localisation sont désactivés. Veuillez les activer dans les paramètres.';
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Les permissions de localisation sont refusées.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Les permissions de localisation sont définitivement refusées. Veuillez les activer dans les paramètres.';
      }

      return true;
    } catch (e) {
      throw 'Erreur lors de la demande de permission: $e';
    }
  }

  /// Obtenir la position actuelle
  Future<Position> getCurrentPosition() async {
    try {
      await requestLocationPermission();
      
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      throw 'Erreur lors de la récupération de la position: $e';
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
      throw 'Erreur lors de la récupération de la localisation: $e';
    }
  }
}

