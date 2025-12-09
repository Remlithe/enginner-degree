// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'parking_screen.dart'; // To jest Twój ekran z żółtym guzikiem
import 'map_screen.dart';
import 'profile_screen.dart';
import 'favorites_screen.dart';

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

      const MapScreen(),
      
      const FavoritesScreen(),

      // 2. PROFIL (Z opcją wylogowania, żebyś nie utknął)
      const ProfileScreen(),
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
            icon: Icon(Icons.favorite), // Serduszko
            label: 'Ulubione',
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