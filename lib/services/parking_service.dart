// lib/services/parking_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parking_area_model.dart'; 

class ParkingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Pobierz listę
  Stream<List<ParkingAreaModel>> getParkingAreas() {
    return _db.collection('parking_spots').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ParkingAreaModel.fromFirestore(
          doc.data(), // Firebase zwraca Map<String, dynamic>
          doc.id
        );
      }).toList();
    });
  }

  // 2. Ulubione
  Stream<List<String>> getUserFavorites() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _db.collection('users').doc(user.uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data()!.containsKey('favorites')) {
        return List<String>.from(snapshot.data()!['favorites']);
      }
      return [];
    });
  }

  // 3. Toggle Favorite
  Future<void> toggleFavorite(String parkingId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    DocumentReference userDoc = _db.collection('users').doc(user.uid);
    DocumentSnapshot doc = await userDoc.get();
    List<String> currentFavs = [];
    if (doc.exists && (doc.data() as Map).containsKey('favorites')) {
      currentFavs = List<String>.from(doc['favorites']);
    }
    if (currentFavs.contains(parkingId)) {
      currentFavs.remove(parkingId);
    } else {
      currentFavs.add(parkingId);
    }
    await userDoc.update({'favorites': currentFavs});
  }

  // 4. Dystans (Matematyka jest ta sama)
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  // 5. Dane testowe (SEED DATA) - Przywracamy, bo ParkingScreen tego używa
  Future<void> seedData() async {
    CollectionReference spots = _db.collection('parking_spots');
    await spots.add({
      'ownerUid': 'test_system',
      'name': 'Galeria Mokotów',
      'address': 'Wołoska 12, Warszawa',
      'location': const GeoPoint(52.1800, 21.0000), 
      'pricePerHour': 0.0,
      'totalCapacity': 500,
      'occupiedSpots': 120,
      'features': ['24/7', 'Kryty'],
    });
    await spots.add({
      'ownerUid': 'test_system',
      'name': 'Parking Centralny',
      'address': 'Marszałkowska 100, Warszawa',
      'location': const GeoPoint(52.2297, 21.0122),
      'pricePerHour': 5.5,
      'totalCapacity': 50,
      'occupiedSpots': 48,
      'features': ['Ochrona'],
    });
  }
}