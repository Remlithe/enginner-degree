// lib/models/parkingareamodel.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // <--- TO JEST POPRAWNY IMPORT DLA OPENSTREETMAP

class ParkingAreaModel {
  final String id;
  final String ownerUid;
  final String name;
  final String address;
  final LatLng location; // Teraz to jest LatLng z paczki latlong2
  final double pricePerHour;
  
  final int totalCapacity;
  final int occupiedSpots;
  final String? description;
  final List<String> features;

  ParkingAreaModel({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.address,
    required this.location,
    required this.pricePerHour,
    required this.totalCapacity,
    this.occupiedSpots = 0,
    this.description,
    this.features = const [],
  });

  bool get isAvailable => occupiedSpots < totalCapacity;

  factory ParkingAreaModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    // Pobieramy GeoPoint z Firebase
    GeoPoint geoPoint = data['location'] as GeoPoint;
    
    return ParkingAreaModel(
      id: documentId,
      ownerUid: data['ownerUid'] ?? '',
      name: data['name'] ?? 'Parking Bez Nazwy',
      address: data['address'] ?? 'Nieznany adres',
      // Konwersja: Firebase GeoPoint -> latlong2 LatLng
      location: LatLng(geoPoint.latitude, geoPoint.longitude),
      pricePerHour: (data['pricePerHour'] as num?)?.toDouble() ?? 0.0,
      totalCapacity: data['totalCapacity'] ?? 1,
      occupiedSpots: data['occupiedSpots'] ?? 0,
      description: data['description'],
      features: List<String>.from(data['features'] ?? []),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'name': name,
      'address': address,
      // Konwersja: latlong2 LatLng -> Firebase GeoPoint
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