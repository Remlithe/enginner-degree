// lib/models/parkingareamodel.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // <--- WRACAMY DO GOOGLE

class ParkingAreaModel {
  final String id;
  final String ownerUid;
  final String name;
  final String address;
  final LatLng location; // Teraz to jest LatLng z Google Maps
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
    GeoPoint geoPoint = data['location'] as GeoPoint;
    
    return ParkingAreaModel(
      id: documentId,
      ownerUid: data['ownerUid'] ?? '',
      name: data['name'] ?? 'Parking',
      address: data['address'] ?? 'Adres',
      location: LatLng(geoPoint.latitude, geoPoint.longitude),
      pricePerHour: (data['pricePerHour'] as num?)?.toDouble() ?? 0.0,
      totalCapacity: data['totalCapacity'] ?? 1,
      occupiedSpots: data['occupiedSpots'] ?? 0,
      description: data['description'],
      features: List<String>.from(data['features'] ?? []),
    );
  }
}