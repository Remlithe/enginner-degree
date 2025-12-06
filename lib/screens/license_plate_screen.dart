// lib/screens/license_plate_screen.dart
import 'package:flutter/material.dart';
import 'payment_setup_screen.dart'; // Upewnij się, że masz ten import

class LicensePlateScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String password;

  const LicensePlateScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
  });

  @override
  State<LicensePlateScreen> createState() => _LicensePlateScreenState();
}

class _LicensePlateScreenState extends State<LicensePlateScreen> {
  final TextEditingController _plateController = TextEditingController();

  void _goToPaymentStep() {
    if (_plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj numer rejestracyjny.')),
      );
      return;
    }

    // --- KLUCZOWA ZMIANA ---
    // Nie rejestrujemy tu użytkownika! Tylko przechodzimy dalej.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => PaymentSetupScreen(
        firstName: widget.firstName,
        lastName: widget.lastName,
        email: widget.email,
        password: widget.password,
        licensePlate: _plateController.text.trim().toUpperCase(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Krok 2/3: Twój Pojazd')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Wprowadź numer rejestracyjny, abyśmy mogli automatycznie rozpoznawać Twój wjazd.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _plateController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'PO 12345',
                  hintStyle: TextStyle(color: Colors.black12, letterSpacing: 4),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ),
            
            const Spacer(),
            
            ElevatedButton(
              onPressed: _goToPaymentStep,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('DALEJ', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}