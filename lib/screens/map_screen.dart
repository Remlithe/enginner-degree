// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart'; // Do nawigacji
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
  
  // ID wybranego parkingu (żeby zmienić kolor na niebieski)
  String? _selectedSpotId;

  BitmapDescriptor? _iconRed;   
  BitmapDescriptor? _iconBlue;  
  BitmapDescriptor? _iconBlack;

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(52.2297, 21.0122), // Warszawa
    zoom: 12,
  );

  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    _locateUser();
  }

Future<void> _loadCustomMarkers() async {
    try {
      // Ładowanie jest asynchroniczne, dlatego używamy await
      final red = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)), 
        'assets/images/pin_red.png'
      );
      final blue = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)), 
        'assets/images/pin_blue.png'
      );
      final black = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)), 
        'assets/images/pin_black.png'
      );

      // Aktualizujemy stan dopiero po załadowaniu wszystkich ikon
      if (mounted) {
        setState(() {
          _iconRed = red;
          _iconBlue = blue;
          _iconBlack = black;
        });
      }
      
    } catch (e) {
      // Fallback w razie błędu ładowania (np. brak pliku)
      print("Błąd ładowania ikon z assets: $e. Użycie domyślnych znaczników.");
      // Domyślne kolory, jeśli pliki nie istnieją
      if (mounted) {
        setState(() {
          _iconRed = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
          _iconBlue = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
          _iconBlack = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        });
      }
    }
  }

  // --- WYBÓR IKONY DLA PINEZKI ---
  BitmapDescriptor _getMarkerIcon(ParkingAreaModel spot) {
    // Jeśli ikony się jeszcze nie załadowały, użyj domyślnego markeru Google.
    if (_iconRed == null || _iconBlue == null || _iconBlack == null) {
      return BitmapDescriptor.defaultMarker;
    }

    // 1. Jeśli wybrany -> NIEBIESKI (Custom)
    if (_selectedSpotId == spot.id) {
      return _iconBlue!;
    }
    
    // 2. Jeśli pełny -> CZERWONY (Custom)
    if (spot.occupiedSpots >= spot.totalCapacity) {
      return _iconRed!;
    }

    // 3. Domyślny -> CZARNY (Custom)
    return _iconBlack!; 
  }
  // --- Funkcja Lokalizacji ---
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
          14
        ),
      );
    }
    if(mounted) setState(() => _isLoadingLocation = false);
  }

  // --- Funkcja Nawigacji (Google Maps) ---
  Future<void> _launchNavigation(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nie można otworzyć mapy')));
    }
  }

  // --- Wyświetlanie Panelu Dolnego (Bottom Sheet) ---
  void _showParkingDetails(BuildContext context, ParkingAreaModel spot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Pozwala nam kontrolować wysokość i paddingi
      backgroundColor: Colors.transparent, // KLUCZOWE: Tło musi być przezroczyste
      isDismissible: true, // Pozwala zamknąć klikając poza
      enableDrag: true, // Pozwala zamknąć przeciągając w dół
      builder: (ctx) => Padding(
        // MARGINESY: 15px od każdego boku i 30px od dołu (żeby "wisiało" nad paskiem nawigacji)
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Zajmuje tylko tyle miejsca ile potrzeba
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                // Zaokrąglamy wszystkie rogi, bo to "pływająca karta"
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  )
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Górna belka (Uchwyt) ---
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300], 
                        borderRadius: BorderRadius.circular(10)
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Treść: Ikona + Opis ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50, 
                          borderRadius: BorderRadius.circular(16)
                        ),
                        child: const Icon(Icons.local_parking, color: Colors.blue, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spot.name, 
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(height: 6),
                            Text(
                              spot.address, 
                              style: const TextStyle(color: Colors.grey, fontSize: 14)
                            ),
                            const SizedBox(height: 8),
                            // Status (Wolne / Zajęte)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: spot.isAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                spot.isAvailable ? "WOLNE MIEJSCA" : "BRAK MIEJSC",
                                style: TextStyle(
                                  color: spot.isAvailable ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Serduszko (Ulubione)
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

                  // --- Przycisk NAWIGUJ ---
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.navigation, color: Colors.white),
                      label: const Text(
                        'NAWIGUJ', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                      onPressed: () {
                        // Zamykamy okienko przed uruchomieniem nawigacji
                        Navigator.pop(ctx); 
                        _launchNavigation(spot.location.latitude, spot.location.longitude);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            builder: (context, snapshot) {
              
              Set<Marker> markers = {};
              if (snapshot.hasData) {
                markers = snapshot.data!.map((spot) {
                  return Marker(
                    markerId: MarkerId(spot.id),
                    position: spot.location,
                    // ZMIANA KOLORU I IKONY:
                    icon: _getMarkerIcon(spot),
                    onTap: () {
                      // 1. Zmień kolor na niebieski (wybrany)
                      setState(() {
                        _selectedSpotId = spot.id;
                      });
                      // 2. Pokaż panel dolny
                      _showParkingDetails(context, spot);
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
                // Reset wyboru po kliknięciu w mapę
                onTap: (_) {
                  setState(() {
                    _selectedSpotId = null;
                  });
                },
              );
            },
          ),
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      // Przycisk "Moja lokalizacja"
      floatingActionButton: FloatingActionButton(
        onPressed: _locateUser,
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.blue),
      ),
    );
  }
}