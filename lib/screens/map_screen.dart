// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Google Maps
import 'package:geolocator/geolocator.dart';
import '../models/parkingareamodel.dart';
import '../services/parking_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ParkingService _parkingService = ParkingService();
  GoogleMapController? _mapController;
  
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(52.2297, 21.0122), // Warszawa
    zoom: 12,
  );

  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  Future<void> _locateUser() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
       if(mounted) setState(() => _isLoadingLocation = false);
       return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
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
    if(mounted) setState(() => _isLoadingLocation = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _locateUser,
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.blue),
      ),
    );
  }
}