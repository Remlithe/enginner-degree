import 'package:cloud_firestore/cloud_firestore.dart'; // Dodano import Firestore
import 'package:flutter/material.dart';
import '../models/parking_area_model.dart';
import '../services/parking_service.dart';
import '../widgets/occupancy_bar.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ParkingService _parkingService = ParkingService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Ulubione parkingi',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      // 1. Pobieramy listę parkingów
      body: StreamBuilder<List<ParkingAreaModel>>(
        stream: _parkingService.getParkingAreas(),
        builder: (context, snapshotParking) {
          // 2. Pobieramy listę ulubionych ID
          return StreamBuilder<List<String>>(
            stream: _parkingService.getUserFavorites(),
            builder: (context, snapshotFavs) {
              // 3. <<< NOWOŚĆ: Pobieramy aktywne sesje (tak jak w ParkingScreen) >>>
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('parking_sessions')
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshotSessions) {
                  
                  if (!snapshotParking.hasData || !snapshotFavs.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // <<< OBLICZANIE ZAJĘTOŚCI NA ŻYWO >>>
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
                  // <<< KONIEC OBLICZEŃ >>>

                  final allSpots = snapshotParking.data!;
                  final favIds = snapshotFavs.data!;
                  
                  final favSpots = allSpots.where((s) => favIds.contains(s.id)).toList();

                  if (favSpots.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          Text('Brak ulubionych parkingów', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: favSpots.length,
                    itemBuilder: (context, index) {
                      final spot = favSpots[index];
                      // Pobieramy prawdziwą liczbę z naszej mapy, a nie z modelu!
                      final realOccupancy = activeCounts[spot.id] ?? 0;
                      
                      return _buildFavoriteCard(spot, realOccupancy);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Zaktualizowałem argumenty funkcji o int currentOccupancy
  Widget _buildFavoriteCard(ParkingAreaModel spot, int currentOccupancy) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: IntrinsicHeight( 
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 80,
              decoration: BoxDecoration(
                color: Colors.blue.shade100.withOpacity(0.5), 
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, color: Colors.blue),
                  const SizedBox(height: 4),
                  Text(
                    "${spot.pricePerHour.toStringAsFixed(0)}zł/1h",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            spot.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            await _parkingService.toggleFavorite(spot.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Usunięto ${spot.name} z ulubionych"),
                                  duration: const Duration(minutes: 1),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.all(10),
                                  action: SnackBarAction(
                                    label: "COFNIJ",
                                    textColor: Colors.yellow,
                                    onPressed: () {
                                      _parkingService.toggleFavorite(spot.id);
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spot.address,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    
                    // --- PASEK POSTĘPU ---
                    // Tutaj przekazujemy obliczoną wartość "currentOccupancy" zamiast tej z bazy "spot.occupiedSpots"
                    OccupancyBar(
                      occupied: currentOccupancy, // <<< UŻYWAMY DANYCH LIVE
                      capacity: spot.totalCapacity,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}