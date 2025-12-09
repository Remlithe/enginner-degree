import 'package:flutter/material.dart';
import '../models/parkingareamodel.dart';
import '../services/parking_service.dart';
import '../widgets/occupancy_bar.dart'; // Import paska, który stworzyliśmy

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
      backgroundColor: Colors.grey[50], // Jasne tło jak na projekcie
      appBar: AppBar(
        title: const Text(
          'Ulubione parkingi',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Usuwa strzałkę wstecz
      ),
      body: StreamBuilder<List<ParkingAreaModel>>(
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
              
              // Filtrujemy listę, zostawiając tylko ulubione
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
                  return _buildFavoriteCard(favSpots[index]);
                },
              );
            },
          );
        },
      ),
    );
  }

  // Budowa pojedynczej karty (Wzorowana na Twoim obrazku)
  Widget _buildFavoriteCard(ParkingAreaModel spot) {
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
      child: IntrinsicHeight( // Ważne: pozwala niebieskiemu paskowi rozciągnąć się na wysokość
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- LEWA STRONA (Niebieski pasek z ceną) ---
            Container(
              width: 80,
              decoration: BoxDecoration(
                color: Colors.blue.shade100.withOpacity(0.5), // Jasny niebieski
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
            
            // --- ŚRODEK (Informacje) ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Górny rząd: Nazwa + Kosz
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
                        // Ikona kosza (Usuwanie)
                        InkWell(
                          onTap: () => _parkingService.toggleFavorite(spot.id),
                          child: const Icon(Icons.delete_outline, color: Colors.blue, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Adres
                    Text(
                      spot.address,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    
                    // --- PASEK POSTĘPU ---
                    OccupancyBar(
                      occupied: spot.occupiedSpots,
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
