import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'profile_subscreens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text("Twój Profil", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. PRZEWIJANA LISTA OPCJI (zajmuje całe dostępne miejsce)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 20),
                child: Column(
                  children: [
                    _buildMenuOption(
                      icon: Icons.person,
                      title: "Dane osobowe",
                      subtitle: "Imię, nazwisko, email, hasło",
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonalDataScreen()));
                      },
                    ),

                    _buildMenuOption(
                      icon: Icons.directions_car,
                      title: "Dane pojazdu",
                      subtitle: "Zarządzaj numerem rejestracyjnym",
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const VehicleDataScreen()));
                      },
                    ),

                    _buildMenuOption(
                      icon: Icons.credit_card,
                      title: "Płatności",
                      subtitle: "Twoja podpięta karta",
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CardDataScreen()));
                      },
                    ),

                    _buildMenuOption(
                      icon: Icons.report_problem,
                      title: "Zgłoś problem",
                      subtitle: "Napisz do nas, jeśli coś nie działa",
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportProblemScreen()));
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 2. PRZYCISK WYLOGUJ (Przyklejony do dołu)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF007AFF),
                    side: const BorderSide(color: Color(0xFF007AFF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text("Wyloguj się", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required VoidCallback onTap
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFF007AFF)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }
}