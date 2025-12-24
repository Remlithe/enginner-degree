import 'package:flutter/material.dart';
import 'parking_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'favorites_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ParkingScreen(),    
    const MapScreen(),        
    const FavoritesScreen(),  
    const ProfileScreen(),    
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      // --- KLUCZOWA ZMIANA ---
      // false = treść kończy się NAD paskiem nawigacji. 
      // Dzięki temu w ParkingScreen bottom:0 to szczyt navbara.
      extendBody: false, 
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  Widget _buildCustomBottomNavBar() {
    return Container(
      // Tło kontenera paska musi pasować do tła aplikacji, żeby cień wyglądał dobrze
      color: const Color(0xFFF2F2F7), 
      child: SafeArea(
        child: Container(
          // Marginesy tworzą efekt "wyspy" (floating), ale fizycznie pasek zajmuje miejsce
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined),
              _buildNavItem(1, Icons.location_on, Icons.location_on_outlined),
              _buildNavItem(2, Icons.favorite, Icons.favorite_border),
              _buildNavItem(3, Icons.person, Icons.person_outline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon) {
    final bool isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade400,
              size: 28,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFF007AFF),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 9),
          ],
        ),
      ),
    );
  }
}