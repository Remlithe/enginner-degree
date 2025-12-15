// lib/screens/parking_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; // <--- Potrzebne do GPS
import '../models/user_model.dart';
import '../models/parking_area_model.dart'; // Upewnij się co do wielkości liter pliku!
import '../services/parking_service.dart';

class ParkingScreen extends StatefulWidget {
  final VoidCallback onFindParking;

  const ParkingScreen({super.key, required this.onFindParking});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ParkingService _parkingService = ParkingService();

  // ZMIANA: Zamiast "na sztywno", używamy zmiennej, która może być null
  Position? _currentPosition;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _determinePosition(); // <--- Pobieramy lokalizację na starcie
  }

  // Funkcja pobierająca prawdziwą lokalizację
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Sprawdź czy GPS jest włączony
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Włącz GPS, aby znaleźć najbliższe parkingi.')));
      }
      return;
    }

    // 2. Sprawdź uprawnienia
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brak uprawnień do lokalizacji.')));
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    // 3. Pobierz pozycję
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print("Błąd lokalizacji: $e");
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('PARK CHECK', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Karta Rejestracji
            _buildLicensePlateCard(),
            const SizedBox(height: 16),

            // 2. Treść Główna
            Expanded(
              child: _isLoadingLocation 
                  ? const Center(child: CircularProgressIndicator()) // Czekamy na GPS
                  : StreamBuilder<List<ParkingAreaModel>>(
                      stream: _parkingService.getParkingAreas(),
                      builder: (context, snapshotParking) {
                        return StreamBuilder<List<String>>(
                          stream: _parkingService.getUserFavorites(),
                          builder: (context, snapshotFavs) {
                            
                            if (!snapshotParking.hasData || !snapshotFavs.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final allSpots = snapshotParking.data!;
                            final favIds = snapshotFavs.data!;

                            return Column(
                              children: [
                                // Sekcja Ulubione
                                Expanded(
                                  flex: 3,
                                  child: _buildFavoritesContainer(allSpots, favIds),
                                ),
                                const SizedBox(height: 16),
                                // Sekcja Najbliższe (Teraz z prawdziwą lokalizacją!)
                                Expanded(
                                  flex: 4,
                                  child: _buildNearestContainer(allSpots, favIds),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicensePlateCard() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 80, child: Center(child: LinearProgressIndicator()));
        }
        
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final plate = data?['licensePlate'] ?? 'BRAK';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0,5))],
          ),
          child: Column(
            children: [
              const Text('TWÓJ POJAZD', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5)),
              const SizedBox(height: 5),
              Text(
                plate,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoritesContainer(List<ParkingAreaModel> allSpots, List<String> favIds) {
    final favSpots = allSpots.where((s) => favIds.contains(s.id)).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.favorite, color: Colors.red), 
            SizedBox(width: 10), 
            Text('Ulubione Parkingi', style: TextStyle(fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 10),
          if (favSpots.isEmpty)
             const Expanded(child: Center(child: Text("Brak ulubionych.")))
          else
            Expanded(
              child: ListView.builder(
                itemCount: favSpots.length,
                itemBuilder: (context, index) {
                  final spot = favSpots[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(spot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(spot.address),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () => _parkingService.toggleFavorite(spot.id),
                    ),
                  );
                },
              ),
            )
        ],
      ),
    );
  }

  Widget _buildNearestContainer(List<ParkingAreaModel> allSpots, List<String> favIds) {
    // Jeśli nie mamy lokalizacji (np. błąd lub brak zgody), nie sortujemy albo używamy domyślnej
    if (_currentPosition != null) {
      allSpots.sort((a, b) {
        double distA = _parkingService.calculateDistance(
          _currentPosition!.latitude, _currentPosition!.longitude, 
          a.location.latitude, a.location.longitude
        );
        double distB = _parkingService.calculateDistance(
          _currentPosition!.latitude, _currentPosition!.longitude, 
          b.location.latitude, b.location.longitude
        );
        return distA.compareTo(distB);
      });
    }
    
    final nearest = allSpots.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('W pobliżu', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          if (_currentPosition == null)
            const Expanded(child: Center(child: Text("Brak lokalizacji")))
          else
            Expanded(
              child: ListView.builder(
                itemCount: nearest.length,
                itemBuilder: (context, index) {
                  final spot = nearest[index];
                  double km = _parkingService.calculateDistance(
                    _currentPosition!.latitude, _currentPosition!.longitude, 
                    spot.location.latitude, spot.location.longitude
                  ) / 1000;
                  
                  bool isFav = favIds.contains(spot.id);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_parking, color: Colors.blue),
                    title: Text(spot.name),
                    // Wyświetlamy dystans z dokładnością do 1 miejsca po przecinku
                    subtitle: Text("${km.toStringAsFixed(1)} km • ${spot.pricePerHour} zł/h"),
                    trailing: IconButton(
                      icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey),
                      onPressed: () => _parkingService.toggleFavorite(spot.id),
                    ),
                  );
                },
              ),
            ),
          
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onFindParking,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text('ZOBACZ NA MAPIE'),
            ),
          )
        ],
      ),
    );
  }
}