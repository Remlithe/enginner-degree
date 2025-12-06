// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart'; // Używamy wcześniej zdefiniowanego modelu

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Pobranie strumienia aktualnego użytkownika
  Stream<User?> get user {
    return _firebaseAuth.authStateChanges();
  }
  
  // 1. Rejestracja nowego Klienta
  // lib/services/auth_service.dart (fragment metody rejestracji)

  Future<UserModel?> registerWithEmailPassword({
  required String email,
  required String password,
  required String firstName,
  required String lastName,
  required String licensePlate,
  required String stripeCustomerId,
  required String paymentMethodId,
  required String cardLast4,
}) async {
  try {
    // Create the user with Firebase Auth
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Create a user model
    final user = UserModel(
      uid: userCredential.user!.uid,
      email: email,
      firstName: firstName,
      lastName: lastName,
      licensePlate: licensePlate,
      stripeCustomerId: stripeCustomerId,
      paymentMethodId: paymentMethodId,
      cardLast4: cardLast4,
    );
    
    // Save the user data to Firestore
    await _firestore.collection('users').doc(user.uid).set(user.toJson());
    
    return user;
  } catch (e) {
    print('Error registering user: $e');
    return null;
  }
}

  // 2. Logowanie istniejącego Klienta/Właściciela
  Future<UserModel?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // Po udanym logowaniu pobieramy pełne dane z Firestore
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
            return UserModel.fromFirestore(doc.data() as Map<String, dynamic>);
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print("Błąd logowania: ${e.message}");
      rethrow;
    }
  }

  // 3. Wylogowanie
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}