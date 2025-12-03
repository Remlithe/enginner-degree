// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // OpenStreetMap
import 'package:latlong2/latlong.dart';      // Współrzędne
import 'package:geolocator/geolocator.dart'; // GPS
import '../models/parkingareamodel.dart';
import '../services/parking_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ParkingService _parkingService = ParkingService();
  final MapController _mapController = MapController();

  LatLng _myLocation = const LatLng(52.2297, 21.0122); 
  bool _hasLocation = false;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  Future<void> _locateUser() async {
    setState(() => _isLoadingLocation = true);

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

    if (mounted) {
      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
        _hasLocation = true;
        _isLoadingLocation = false;
      });
      _mapController.move(_myLocation, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<List<ParkingAreaModel>>(
            stream: _parkingService.getParkingAreas(),
            builder: (context, snapshot) {
              List<Marker> markers = [];
              if (snapshot.hasData) {
                markers = snapshot.data!.map((spot) {
                  return Marker(
                    point: spot.location,
                    width: 40, height: 40,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                  );
                }).toList();
              }
              if (_hasLocation) {
                markers.add(Marker(
                  point: _myLocation, width: 30, height: 30,
                  child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                ));
              }

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: _myLocation, initialZoom: 13.0),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),
          if (_isLoadingLocation) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _locateUser,
        child: const Icon(Icons.gps_fixed),
      ),
    );
  }
}