import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart'; 

class ParkingAreaModel {
  final String id; // ID dokumentu w Firestore
  final String ownerUid; // ID właściciela tego obszaru
  final String address;
  final LatLng location; // Szerokość i długość geograficzna
  final double pricePerHour;
  
  // KLUCZOWE ZMIANY: pojemność i zajęte miejsca
  final int totalCapacity; // Całkowita liczba miejsc na tym obszarze
  final int occupiedSpots; // Aktualnie zajęte miejsca (kontrolowane przez Właściciela i Rezerwacje)

  final String? description;
  final List<String> features; // Zamiast bool, użyjmy listy cech (np. ['24/7', 'EV', 'Ochrona'])

  ParkingAreaModel({
    required this.id,
    required this.ownerUid,
    required this.address,
    required this.location,
    required this.pricePerHour,
    required this.totalCapacity,
    this.occupiedSpots = 0,
    this.description,
    this.features = const [],
  });

  // Czy są wolne miejsca? Uproszczona logika dla Klienta
  bool get isAvailable {
    return occupiedSpots < totalCapacity;
  }
  
  // Metoda do tworzenia obiektu z danych Firestore
  factory ParkingAreaModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    GeoPoint geoPoint = data['location'] as GeoPoint;
    
    return ParkingAreaModel(
      id: documentId,
      ownerUid: data['ownerUid'] ?? '',
      address: data['address'] ?? 'Nieznany adres',
      location: LatLng(geoPoint.latitude, geoPoint.longitude),
      pricePerHour: (data['pricePerHour'] as num?)?.toDouble() ?? 0.0,
      totalCapacity: data['totalCapacity'] ?? 1, // Domyślnie 1, jeśli brak
      occupiedSpots: data['occupiedSpots'] ?? 0,
      description: data['description'],
      features: List<String>.from(data['features'] ?? []),
    );
  }
  
  // Metoda do konwersji obiektu na dane do zapisania w Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'address': address,
      'location': GeoPoint(location.latitude, location.longitude),
      'pricePerHour': pricePerHour,
      'totalCapacity': totalCapacity,
      'occupiedSpots': occupiedSpots,
      'description': description,
      'features': features,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    };
  }
}