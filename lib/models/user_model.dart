// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String licensePlate; // <--- NOWE POLE
  final bool isOwner;

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.licensePlate, // <--- NOWE
    this.isOwner = false,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      licensePlate: data['licensePlate'] ?? 'BRAK', // <--- NOWE
      isOwner: data['isOwner'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'licensePlate': licensePlate, // <--- NOWE
      'isOwner': isOwner,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}