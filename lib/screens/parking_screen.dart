// lib/screens/parking_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; 
import '../models/user_model.dart';
import '../models/parkingareamodel.dart'; // Upewnij się co do nazwy pliku
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

  // Symulowana pozycja (Warszawa Centrum) - docelowo użyj Geolocator.getCurrentPosition()
  final double myLat = 52.2297;
  final double myLng = 21.0122;
  
  // Czy jesteśmy blisko jakiegoś parkingu (na razie false)
  bool isNearParking = false; 

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
        child: StreamBuilder<List<ParkingAreaModel>>(
          stream: _parkingService.getParkingAreas(), // 1. Strumień Parkingów
          builder: (context, snapshotParking) {
            return StreamBuilder<List<String>>(
              stream: _parkingService.getUserFavorites(), // 2. Strumień Ulubionych
              builder: (context, snapshotFavs) {
                
                // Obsługa ładowania
                if (!snapshotParking.hasData || !snapshotFavs.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allSpots = snapshotParking.data!;
                final favIds = snapshotFavs.data!;

                return Column(
                  children: [
                    // 1. KONTENER: NUMER REJESTRACYJNY
                    _buildLicensePlateCard(),
                    
                    const SizedBox(height: 16),
                    
                    // 2. KONTENER: ULUBIONE (Dynamiczne)
                    Expanded(
                      flex: 3, 
                      child: _buildFavoritesContainer(allSpots, favIds),
                    ),

                    const SizedBox(height: 16),

                    // 3. KONTENER: NAJBLIŻSZE (Dynamiczne + Sortowanie)
                    Expanded(
                      flex: 4, 
                      child: _buildNearestAndButtonContainer(allSpots, favIds),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      // PRZYCISK TESTOWY (Usuń go, gdy dodasz parkingi)
      floatingActionButton: FloatingActionButton(
        onPressed: () => _parkingService.seedData(),
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // --- Widget 1: Karta Rejestracji ---
  Widget _buildLicensePlateCard() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 80, child: Center(child: LinearProgressIndicator()));
        }
        
        UserModel? user;
        if (snapshot.hasData && snapshot.data!.data() != null) {
          user = UserModel.fromFirestore(snapshot.data!.data() as Map<String, dynamic>);
        }

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
                user?.licensePlate ?? 'BRAK',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Widget 2: Ulubione ---
  Widget _buildFavoritesContainer(List<ParkingAreaModel> allSpots, List<String> favIds) {
    // Filtrujemy parkingi, które są na liście ulubionych
    final favSpots = allSpots.where((s) => favIds.contains(s.id)).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.favorite, color: Colors.red),
              SizedBox(width: 10),
              Text('Ulubione Parkingi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          
          favSpots.isEmpty
            ? Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      const Text('Nie masz polubionych parkingów', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            : Expanded(
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
              ),
        ],
      ),
    );
  }

  // --- Widget 3: Najbliższe + Guzik ---
  Widget _buildNearestAndButtonContainer(List<ParkingAreaModel> allSpots, List<String> favIds) {
    // 1. Sortuj według odległości
    allSpots.sort((a, b) {
      double distA = _parkingService.calculateDistance(myLat, myLng, a.location.latitude, a.location.longitude);
      double distB = _parkingService.calculateDistance(myLat, myLng, b.location.latitude, b.location.longitude);
      return distA.compareTo(distB);
    });

    // 2. Weź 5 najbliższych
    final nearest = allSpots.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('W pobliżu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          
          Expanded(
            child: ListView.builder(
              itemCount: nearest.length,
              itemBuilder: (context, index) {
                final spot = nearest[index];
                double km = _parkingService.calculateDistance(myLat, myLng, spot.location.latitude, spot.location.longitude) / 1000;
                bool isFav = favIds.contains(spot.id);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.local_parking, color: Colors.blue),
                  ),
                  title: Text(spot.name),
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
          
          // --- GUZIK (Logika się nie zmienia) ---
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isNearParking ? () { print("Start!"); } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, 
                disabledBackgroundColor: Colors.yellow[700], 
                disabledForegroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isNearParking ? 'ROZPOCZNIJ PARKOWANIE' : 'NIE JESTEŚ W POBLIŻU PARKINGU',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}