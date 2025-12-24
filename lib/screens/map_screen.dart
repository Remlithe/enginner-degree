import 'dart:async';
import 'dart:typed_data'; // <<< NOWY IMPORT konieczny do obsługi bitów
import 'dart:ui' as ui;   // <<< NOWY IMPORT konieczny do skalowania obrazu
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <<< NOWY IMPORT do rootBundle
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/parking_area_model.dart';
import '../services/parking_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ParkingService _parkingService = ParkingService();
  GoogleMapController? _mapController;
  
  String? _selectedSpotId;
  String? _activeParkingId; 
  StreamSubscription? _sessionSubscription;

  BitmapDescriptor? _iconRed;   
  BitmapDescriptor? _iconBlue;  
  BitmapDescriptor? _iconBlack;

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(52.2297, 21.0122),
    zoom: 12,
  );

  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    _locateUser();
    _listenToActiveSession();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _listenToActiveSession() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _sessionSubscription = FirebaseFirestore.instance
        .collection('parking_sessions')
        .where('driverId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        if (mounted) {
          setState(() {
            _activeParkingId = data['parkingId'];
          });
        }
      } else {
        if (mounted && _activeParkingId != null) {
          setState(() {
            _activeParkingId = null;
          });
        }
      }
    });
  }

  // --- NOWA METODA POMOCNICZA DO SKALOWANIA IKON ---
  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }
  // -------------------------------------------------

  Future<void> _loadCustomMarkers() async {
    try {
      // --- TUTAJ ZMIENIASZ ROZMIAR IKON ---
      // Ustawiamy docelową szerokość w pikselach.
      // Zacznij od 120. Jeśli nadal za duże, zmniejsz np. do 100 lub 80.
      const int targetWidth = 100; 

      final Uint8List redBytes = await getBytesFromAsset('assets/images/pin_red.png', targetWidth);
      final Uint8List blueBytes = await getBytesFromAsset('assets/images/pin_blue.png', targetWidth);
      final Uint8List blackBytes = await getBytesFromAsset('assets/images/pin_black.png', targetWidth);

      final red = BitmapDescriptor.fromBytes(redBytes);
      final blue = BitmapDescriptor.fromBytes(blueBytes);
      final black = BitmapDescriptor.fromBytes(blackBytes);

      if (mounted) {
        setState(() {
          _iconRed = red;
          _iconBlue = blue;
          _iconBlack = black;
        });
      }
      
    } catch (e) {
      print("Błąd ładowania ikon z assets: $e");
      // Fallback do domyślnych, jeśli coś pójdzie nie tak
      if (mounted) {
        setState(() {
          _iconRed = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
          _iconBlue = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
          _iconBlack = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        });
      }
    }
  }

  BitmapDescriptor _getMarkerIcon(ParkingAreaModel spot, int realOccupancy) {
    if (_iconRed == null || _iconBlue == null || _iconBlack == null) {
      return BitmapDescriptor.defaultMarker;
    }

    if (_activeParkingId == spot.id) {
      return _iconBlue!;
    }

    if (_selectedSpotId == spot.id) {
      return _iconBlue!;
    }
    
    if (realOccupancy >= spot.totalCapacity) {
      return _iconRed!;
    }

    return _iconBlack!; 
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

    try {
      Position position = await Geolocator.getCurrentPosition();

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude), 
            14
          ),
        );
      }
    } catch (e) {
      print("Błąd lokalizacji: $e");
    } finally {
      if(mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nie można otworzyć mapy')));
      }
    }
  }

  void _showParkingDetails(BuildContext context, ParkingAreaModel spot, int realOccupancy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      isDismissible: true,
      enableDrag: true, 
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 5))
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.local_parking, color: Colors.blue, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(spot.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(spot.address, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                              const SizedBox(height: 8),
                              
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (realOccupancy < spot.totalCapacity) ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (realOccupancy < spot.totalCapacity) 
                                    ? "WOLNE MIEJSCA (${spot.totalCapacity - realOccupancy})" 
                                    : "BRAK MIEJSC",
                                  style: TextStyle(
                                    color: (realOccupancy < spot.totalCapacity) ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        StreamBuilder<List<String>>(
                          stream: _parkingService.getUserFavorites(),
                          builder: (context, snapshot) {
                            bool isFav = false;
                            if (snapshot.hasData) {
                              isFav = snapshot.data!.contains(spot.id);
                            }
                            return IconButton(
                              icon: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? Colors.red : Colors.grey[400],
                                size: 28,
                              ),
                              onPressed: () => _parkingService.toggleFavorite(spot.id),
                            );
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.navigation, color: Colors.white),
                        label: const Text('NAWIGUJ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx); 
                          _launchNavigation(spot.location.latitude, spot.location.longitude);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<List<ParkingAreaModel>>(
            stream: _parkingService.getParkingAreas(),
            builder: (context, snapshotSpots) {
              
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                  .collection('parking_sessions')
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
                builder: (context, snapshotSessions) {

                  Map<String, int> activeCounts = {};
                  if (snapshotSessions.hasData) {
                    for (var doc in snapshotSessions.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final pId = data['parkingId'] as String?;
                      if (pId != null) {
                        activeCounts[pId] = (activeCounts[pId] ?? 0) + 1;
                      }
                    }
                  }

                  Set<Marker> markers = {};
                  if (snapshotSpots.hasData) {
                    markers = snapshotSpots.data!.map((spot) {
                      int realOccupancy = activeCounts[spot.id] ?? 0;

                      return Marker(
                        markerId: MarkerId(spot.id),
                        position: spot.location,
                        icon: _getMarkerIcon(spot, realOccupancy),
                        onTap: () {
                          setState(() {
                            _selectedSpotId = spot.id;
                          });
                          _showParkingDetails(context, spot, realOccupancy);
                        },
                      );
                    }).toSet();
                  }

                  return GoogleMap(
                    initialCameraPosition: _initialCamera,
                    markers: markers,
                    myLocationEnabled: true, 
                    myLocationButtonEnabled: false, 
                    zoomControlsEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _locateUser(); 
                    },
                    onTap: (_) {
                      setState(() {
                        _selectedSpotId = null;
                      });
                    },
                  );
                }
              );
            },
          ),
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _locateUser,
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.blue),
      ),
    );
  }
}