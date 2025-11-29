// lib/screens/parking_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class ParkingScreen extends StatefulWidget {
  final VoidCallback onFindParking;

  const ParkingScreen({super.key, required this.onFindParking});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  
  // Symulacja, czy jesteśmy blisko (na razie false, żeby guzik był żółty i nieaktywny)
  bool isNearParking = false; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Jasne tło
      appBar: AppBar(
        title: const Text('PARK CHECK', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. KONTENER: NUMER REJESTRACYJNY
            _buildLicensePlateCard(),
            
            const SizedBox(height: 16),
            
            // 2. KONTENER: ULUBIONE PARKINGI
            Expanded(
              flex: 3, // Zajmie trochę miejsca
              child: _buildFavoritesContainer(),
            ),

            const SizedBox(height: 16),

            // 3. KONTENER: NAJBLIŻSZE I GUZIK
            Expanded(
              flex: 4, // Zajmie więcej miejsca na dole
              child: _buildNearestAndButtonContainer(),
            ),
          ],
        ),
      ),
    );
  }

  // Widget 1: Karta z numerem rejestracyjnym
  Widget _buildLicensePlateCard() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        
        // Pobieramy dane użytkownika z bazy
        UserModel? user;
        if (snapshot.hasData && snapshot.data!.data() != null) {
          user = UserModel.fromFirestore(snapshot.data!.data() as Map<String, dynamic>);
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0,5))],
          ),
          child: Column(
            children: [
              const Text('TWÓJ POJAZD', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5)),
              const SizedBox(height: 5),
              Text(
                user?.licensePlate ?? 'BRAK',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ],
          ),
        );
      },
    );
  }

  // Widget 2: Ulubione (Puste)
  Widget _buildFavoritesContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.favorite, color: Colors.red),
              SizedBox(width: 10),
              Text('Ulubione Parkingi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Icon(Icons.favorite_border, size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                const Text('Nie masz polubionych parkingów', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // Widget 3: Najbliższe + Guzik
  Widget _buildNearestAndButtonContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('W pobliżu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          // Lista najbliższych (zaślepka)
          Expanded(
            child: ListView(
              children: [
                _buildParkingListItem('Parking Centralny', '500m'),
                _buildParkingListItem('Galeria Handlowa', '1.2km'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // --- GUZIK ---
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: isNearParking 
                  ? () { print("Rozpoczynam parkowanie!"); } // Akcja, gdy blisko (później)
                  : null, // NULL oznacza, że guzik jest nieaktywny (disabled)
              style: ElevatedButton.styleFrom(
                // Kiedy aktywny (później):
                backgroundColor: Colors.blue, 
                // Kiedy nieaktywny (teraz):
                disabledBackgroundColor: Colors.yellow[700], 
                disabledForegroundColor: Colors.black, // Kolor tekstu na żółtym
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isNearParking ? 'ROZPOCZNIJ PARKOWANIE' : 'NIE JESTEŚ W POBLIŻU PARKINGU',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkingListItem(String name, String distance) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.local_parking, color: Colors.blue),
      ),
      title: Text(name),
      trailing: Text(distance, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}