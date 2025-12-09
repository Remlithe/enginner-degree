// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'profile_subscreens.dart'; // <--- Importuj nowe ekrany

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // FUNKCJA ANIMACJI (Przesunięcie w prawo)
  void _navigateTo(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0); // Start z prawej
          const end = Offset.zero;        // Koniec na środku
          const curve = Curves.ease;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('KONTO UŻYTKOWNIKA', style: TextStyle(color: Colors.black, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          
          // NAGŁÓWEK
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
            builder: (context, snapshot) {
              String name = "Kierowco";
              if (snapshot.hasData && snapshot.data!.data() != null) {
                final userData = UserModel.fromFirestore(snapshot.data!.data() as Map<String, dynamic>);
                name = "${userData.firstName} ${userData.lastName}";
              }
              return Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Witaj, $name",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),

          // MENU
          Expanded(
            child: ListView(
              children: [
                _buildMenuItem(
                  context, 
                  Icons.person_outline, 
                  "Dane osobowe", 
                  () => _navigateTo(context, const PersonalDataScreen())
                ),
                _buildMenuItem(
                  context, 
                  Icons.credit_card, 
                  "Dane karty", // Zmienione z Bank Link na Dane karty
                  () => _navigateTo(context, const CardDataScreen())
                ),
                _buildMenuItem(
                  context, 
                  Icons.directions_car, // Ikona auta
                  "Dane pojazdu", 
                  () => _navigateTo(context, const VehicleDataScreen())
                ),
                _buildMenuItem(
                  context, 
                  Icons.mail_outline, 
                  "Zgłoś problem", 
                  () => _navigateTo(context, const ReportProblemScreen())
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextButton(
              onPressed: () => AuthService().signOut(),
              child: const Text("WYLOGUJ", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: ListTile(
          leading: Icon(icon, color: Colors.blue),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
      ),
    );
  }
}