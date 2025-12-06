// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          
          // NAGŁÓWEK: "Witaj Jan Kowalski"
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
                    "Witaj $name",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),

          // LISTA OPCJI (Menu)
          Expanded(
            child: ListView(
              children: [
                _buildMenuItem(Icons.person_outline, "Dane osobowe", () {}),
                _buildMenuItem(Icons.credit_card, "Bank Link", () {}), // Karty
                _buildMenuItem(Icons.history, "Historia parkowania", () {}),
                _buildMenuItem(Icons.settings, "Ustawienia", () {}),
              ],
            ),
          ),

          // PRZYCISK WYLOGOWANIA NA DOLE
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

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}