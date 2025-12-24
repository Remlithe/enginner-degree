// lib/models/user_model.dart

class UserModel {
  final String uid;  // or id, depending on what you've named it
  final String email;
  final String firstName;
  final String lastName;
  final String licensePlate;
  final String stripeCustomerId;
  final String paymentMethodId;
  final String cardLast4;
  
  UserModel({
    required this.uid,  // or this.id
    required this.email,
    required this.firstName,
    required this.lastName, 
    required this.licensePlate,
    required this.stripeCustomerId,
    required this.paymentMethodId,
    required this.cardLast4,
  });
  
  // Convert UserModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,  // use 'id' if that's what you've named it
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'licensePlate': licensePlate,
      'stripeCustomerId': stripeCustomerId,
      'paymentMethodId': paymentMethodId,
      'cardLast4': cardLast4,
    };
  }
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      licensePlate: data['licensePlate'] ?? 'BRAK',
      stripeCustomerId: data['stripeCustomerId'],
      paymentMethodId: data['paymentMethodId'], // <---
      cardLast4: data['cardLast4'],
    );
  }

  
}