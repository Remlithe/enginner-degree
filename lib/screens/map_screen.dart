// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Google Maps
<<<<<<< HEAD
import 'package:geolocator/geolocator.dart'; // GPS
=======
import 'package:geolocator/geolocator.dart';
>>>>>>> feature/google-maps
import '../models/parkingareamodel.dart';
import '../services/parking_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ParkingService _parkingService = ParkingService();
<<<<<<< HEAD
  
  // Kontroler Google Maps
  GoogleMapController? _mapController;

  // Domyślna pozycja (Warszawa)
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(52.2297, 21.0122),
    zoom: 14,
=======
  GoogleMapController? _mapController;
  
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(52.2297, 21.0122), // Warszawa
    zoom: 12,
>>>>>>> feature/google-maps
  );

  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  // Funkcja: Znajdź mnie i przesuń tam kamerę
  Future<void> _locateUser() async {
<<<<<<< HEAD
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
=======
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
>>>>>>> feature/google-maps
    if (!serviceEnabled) {
       if(mounted) setState(() => _isLoadingLocation = false);
       return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
         if(mounted) setState(() => _isLoadingLocation = false);
         return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude), 
          15
        ),
      );
    }
<<<<<<< HEAD
    
=======
>>>>>>> feature/google-maps
    if(mounted) setState(() => _isLoadingLocation = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
<<<<<<< HEAD
      body: Stack(
        children: [
          StreamBuilder<List<ParkingAreaModel>>(
            stream: _parkingService.getParkingAreas(),
            builder: (context, snapshot) {
              Set<Marker> markers = {};

              if (snapshot.hasData) {
                markers = snapshot.data!.map((spot) {
                  return Marker(
                    markerId: MarkerId(spot.id),
                    position: spot.location,
                    infoWindow: InfoWindow(
                      title: spot.name,
                      snippet: "${spot.pricePerHour} zł/h",
                    ),
                  );
                }).toSet();
              }

              return GoogleMap(
                initialCameraPosition: _initialCamera,
                markers: markers,
                myLocationEnabled: true, // Niebieska kropka
                myLocationButtonEnabled: false, // Ukrywamy domyślny przycisk (zrobimy własny)
                zoomControlsEnabled: false,
                onMapCreated: (controller) {
                  _mapController = controller;
                  // Jak tylko mapa się stworzy, spróbuj wycentrować
                  if (!_isLoadingLocation) _locateUser();
                },
=======
      body: StreamBuilder<List<ParkingAreaModel>>(
        stream: _parkingService.getParkingAreas(),
        builder: (context, snapshot) {
          
          Set<Marker> markers = {};
          if (snapshot.hasData) {
            markers = snapshot.data!.map((spot) {
              return Marker(
                markerId: MarkerId(spot.id),
                position: spot.location, // LatLng z modelu
                infoWindow: InfoWindow(
                  title: spot.name,
                  snippet: "${spot.pricePerHour} zł/h",
                ),
>>>>>>> feature/google-maps
              );
            }).toSet();
          }

          return GoogleMap(
            initialCameraPosition: _initialCamera,
            markers: markers,
            myLocationEnabled: true, // Niebieska kropka
            myLocationButtonEnabled: false, 
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              _locateUser(); 
            },
<<<<<<< HEAD
          ),
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator()),
        ],
=======
          );
        },
>>>>>>> feature/google-maps
      ),
      // NASZ WŁASNY GUZIK LOKALIZACJI
      floatingActionButton: FloatingActionButton(
        onPressed: _locateUser,
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.blue),
      ),
    );
  }
}