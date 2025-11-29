// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'parking_screen.dart'; // To jest Twój ekran z żółtym guzikiem
import '../services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Startujemy od Parkowania (Index 0)

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Funkcja, która przełącza na zakładkę nr 1 (tą pustą mapę)
  void _goToMapPlaceholder() {
    setState(() {
      _selectedIndex = 1; 
    });
  }

  @override
  Widget build(BuildContext context) {
    // LISTA EKRANÓW
    final List<Widget> screens = [
      // 0. PARKOWANIE (Twój gotowy ekran)
      ParkingScreen(onFindParking: _goToMapPlaceholder),

      // 1. ZAMIAST MAPY -> PUSTY EKRAN (Placeholder)
      const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 100, color: Colors.grey),
              SizedBox(height: 20),
              Text("Tu kiedyś będzie mapa"),
            ],
          ),
        ),
      ),

      // 2. PROFIL (Z opcją wylogowania, żebyś nie utknął)
      Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              AuthService().signOut();
            },
            child: const Text('WYLOGUJ SIĘ'),
          ),
        ),
      ),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_parking),
            label: 'Parkowanie',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Konto',
          ),
        ],
      ),
    );
  }
}