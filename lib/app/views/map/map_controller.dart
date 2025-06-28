import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapController extends GetxController {
  final Completer<GoogleMapController> _mapController = Completer();
  
  final Rx<LatLng?> _currentLocation = Rx<LatLng?>(null);
  final RxSet<Marker> _markers = <Marker>{}.obs;
  final RxSet<Polygon> _polygons = <Polygon>{}.obs;
  final RxSet<Circle> _circles = <Circle>{}.obs;
  final RxBool _isLoading = true.obs;
  final RxString _locationStatus = 'Getting location...'.obs;
  final Rx<MapType> _mapType = MapType.normal.obs;
  
  LatLng? get currentLocation => _currentLocation.value;
  Set<Marker> get markers => _markers;
  Set<Polygon> get polygons => _polygons;
  Set<Circle> get circles => _circles;
  bool get isLoading => _isLoading.value;
  String get locationStatus => _locationStatus.value;
  MapType get mapType => _mapType.value;
  
  StreamSubscription<Position>? _positionStreamSubscription;
  
  @override
  void onInit() {
    super.onInit();
    _initializeLocation();
  }
  
  @override
  void onClose() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // Clear collections to prevent memory leaks
    _markers.clear();
    _polygons.clear();
    _circles.clear();

    super.onClose();
  }
  
  Future<void> _initializeLocation() async {
    try {
      _locationStatus.value = 'Checking permissions...';
      
      // Check and request location permissions
      final permission = await _checkLocationPermission();
      if (!permission) {
        _locationStatus.value = 'location_permission_denied'.tr;
        _isLoading.value = false;
        return;
      }
      
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationStatus.value = 'location_service_disabled'.tr;
        _isLoading.value = false;
        return;
      }
      
      _locationStatus.value = 'Getting current location...';
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _updateLocation(LatLng(position.latitude, position.longitude));
      
      // Start listening to location changes
      _startLocationTracking();
      
    } catch (e) {
      _locationStatus.value = 'Error getting location: $e';
      _isLoading.value = false;
    }
  }
  
  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }
  
  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );
    
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateLocation(LatLng(position.latitude, position.longitude));
    });
  }
  
  void _updateLocation(LatLng location) {
    _currentLocation.value = location;
    _locationStatus.value = 'current_location'.tr;
    _isLoading.value = false;
    
    // Update markers
    _updateMarkers(location);
    
    // Update 2km rectangular boundary
    _update2kmBoundary(location);
    
    // Simulate water bodies (in a real app, you'd use a water bodies API)
    _addWaterBodies(location);
    
    // Move camera to current location
    _moveCameraToLocation(location);
  }
  
  void _updateMarkers(LatLng location) {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: 'current_location'.tr,
          snippet: 'Lat: ${location.latitude.toStringAsFixed(6)}, Lng: ${location.longitude.toStringAsFixed(6)}',
        ),
      ),
    );
  }
  
  void _update2kmBoundary(LatLng center) {
    _polygons.clear();
    
    // Calculate 2km rectangular boundary
    const double distance = 2000; // 2km in meters
    const double earthRadius = 6371000; // Earth radius in meters
    
    double latOffset = distance / earthRadius * (180 / pi);
    double lngOffset = distance / (earthRadius * cos(center.latitude * pi / 180)) * (180 / pi);
    
    List<LatLng> rectanglePoints = [
      LatLng(center.latitude + latOffset, center.longitude - lngOffset), // Top-left
      LatLng(center.latitude + latOffset, center.longitude + lngOffset), // Top-right
      LatLng(center.latitude - latOffset, center.longitude + lngOffset), // Bottom-right
      LatLng(center.latitude - latOffset, center.longitude - lngOffset), // Bottom-left
    ];
    
    _polygons.add(
      Polygon(
        polygonId: const PolygonId('2km_boundary'),
        points: rectanglePoints,
        strokeColor: Colors.blue,
        strokeWidth: 2,
        fillColor: Colors.blue.withValues(alpha: 0.1),
      ),
    );
  }
  
  void _addWaterBodies(LatLng center) {
    _circles.clear();
    
    // Simulate some water bodies near the current location
    // In a real app, you would fetch this data from a water bodies API
    List<Map<String, dynamic>> waterBodies = [
      {
        'name': 'Lake Alpha',
        'lat': center.latitude + 0.005,
        'lng': center.longitude + 0.008,
        'radius': 200.0,
      },
      {
        'name': 'Pond Beta',
        'lat': center.latitude - 0.003,
        'lng': center.longitude - 0.006,
        'radius': 100.0,
      },
      {
        'name': 'River Gamma',
        'lat': center.latitude + 0.002,
        'lng': center.longitude - 0.004,
        'radius': 150.0,
      },
    ];
    
    for (int i = 0; i < waterBodies.length; i++) {
      final waterBody = waterBodies[i];
      _circles.add(
        Circle(
          circleId: CircleId('water_body_$i'),
          center: LatLng(waterBody['lat'], waterBody['lng']),
          radius: waterBody['radius'],
          fillColor: Colors.lightBlue.withValues(alpha: 0.5),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
      
      // Add marker for water body
      _markers.add(
        Marker(
          markerId: MarkerId('water_marker_$i'),
          position: LatLng(waterBody['lat'], waterBody['lng']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: waterBody['name'],
            snippet: 'Water body',
          ),
        ),
      );
    }
  }
  
  Future<void> _moveCameraToLocation(LatLng location) async {
    try {
      if (!_mapController.isCompleted) {
        print('Map controller not ready, skipping camera animation');
        return;
      }

      final GoogleMapController controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 14.0,
          ),
        ),
      );
    } catch (e) {
      print('Error moving camera to location: $e');
      // Don't rethrow - this is not critical for app functionality
    }
  }
  
  void onMapCreated(GoogleMapController controller) {
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
    }
  }
  
  Future<void> refreshLocation() async {
    if (_isLoading.value) {
      print('Location refresh already in progress, skipping...');
      return;
    }

    try {
      _isLoading.value = true;
      _locationStatus.value = 'Refreshing location...';

      // Cancel existing location tracking
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;

      // Clear existing data
      _markers.clear();
      _polygons.clear();
      _circles.clear();

      // Reinitialize location
      await _initializeLocation();
    } catch (e) {
      _locationStatus.value = 'Error refreshing location: $e';
      _isLoading.value = false;
      print('Error in refreshLocation: $e');
    }
  }
  
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  void changeMapType(MapType type) {
    _mapType.value = type;
  }

  void goBack() {
    Get.back();
  }
}
