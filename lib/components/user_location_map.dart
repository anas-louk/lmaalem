import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../core/services/location_service.dart';
import '../core/constants/app_colors.dart';

/// Widget de carte avec localisation en temps réel
/// Style InDrive avec design moderne
class UserLocationMap extends StatefulWidget {
  final double height;
  final double borderRadius;
  final bool showCurrentLocationButton;
  final Function(LatLng)? onLocationChanged;

  const UserLocationMap({
    super.key,
    this.height = 240,
    this.borderRadius = 20,
    this.showCurrentLocationButton = true,
    this.onLocationChanged,
  });

  @override
  State<UserLocationMap> createState() => _UserLocationMapState();
}

class _UserLocationMapState extends State<UserLocationMap> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  
  StreamSubscription<Position>? _positionStreamSubscription;
  LatLng? _currentPosition;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isListening = false;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  /// Initialiser la localisation et commencer l'écoute
  Future<void> _initializeLocation() async {
    try {
      // Demander les permissions
      await _locationService.requestLocationPermission();
      
      // Obtenir la position actuelle
      final position = await _locationService.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _currentPosition = latLng;
          _isLoading = false;
          _hasError = false;
        });
        
        // Attendre que la carte soit rendue avant d'utiliser le contrôleur
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isMapReady) {
            _mapController.move(latLng, 15.0);
          }
        });
        
        // Notifier le callback
        widget.onLocationChanged?.call(latLng);
        
        // Commencer l'écoute des changements de position
        _startLocationStream();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString().replaceAll('LocationException: ', '');
        });
      }
    }
  }

  /// Démarrer l'écoute des changements de position en temps réel
  void _startLocationStream() {
    if (_isListening) return;
    
    _isListening = true;
    
    // Écouter les changements de position avec une distance minimale de 10 mètres
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Mettre à jour seulement si l'utilisateur se déplace de 10m
      ),
    ).listen(
      (Position position) {
        if (!mounted) return;
        
        final latLng = LatLng(position.latitude, position.longitude);
        
        setState(() {
          _currentPosition = latLng;
        });
        
        // Animer la caméra vers la nouvelle position (smooth update) seulement si la carte est prête
        if (_isMapReady) {
          _mapController.move(latLng, _mapController.camera.zoom);
        }
        
        // Notifier le callback
        widget.onLocationChanged?.call(latLng);
      },
      onError: (error) {
        if (mounted) {
          debugPrint('Erreur dans le stream de localisation: $error');
          // Ne pas afficher d'erreur pour les erreurs temporaires du stream
        }
      },
    );
  }

  /// Recentrer la carte sur la position actuelle
  Future<void> _centerOnCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _currentPosition = latLng;
        });
        
        // Animer la caméra vers la nouvelle position seulement si la carte est prête
        if (_isMapReady) {
          _mapController.move(latLng, 15.0);
        }
        
        widget.onLocationChanged?.call(latLng);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceAll('LocationException: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          children: [
            // Carte
            if (_isLoading)
              Container(
                color: AppColors.greyLight,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              )
            else if (_hasError || _currentPosition == null)
              Container(
                color: AppColors.greyLight,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ?? 'Localisation non disponible',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _initializeLocation,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPosition!,
                  initialZoom: 15.0,
                  minZoom: 10.0,
                  maxZoom: 18.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    // Marquer la carte comme prête
                    if (mounted) {
                      setState(() {
                        _isMapReady = true;
                      });
                      // Centrer la carte sur la position actuelle maintenant qu'elle est prête
                      if (_currentPosition != null) {
                        _mapController.move(_currentPosition!, 15.0);
                      }
                    }
                  },
                ),
                children: [
                  // Tuiles OpenStreetMap
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.lmaalem',
                    maxZoom: 19,
                  ),
                  // Marqueur de position actuelle
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentPosition!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            
            // Bouton pour recentrer sur la position actuelle
            if (!_isLoading && !_hasError && widget.showCurrentLocationButton)
              Positioned(
                bottom: 12,
                right: 12,
                child: Material(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 4,
                  child: InkWell(
                    onTap: _centerOnCurrentLocation,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.greyLight,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.my_location,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

