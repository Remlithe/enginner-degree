// lib/screens/license_plate_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LicensePlateScreen extends StatefulWidget {
  // Pola, które otrzymujemy z poprzedniego ekranu
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
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _finishRegistration() async {
    if (_plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj numer rejestracyjny.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TU DOPIERO REJESTRUJEMY W FIREBASE
      // Używamy danych z widget.email, widget.password itp.
      await _authService.registerWithEmailPassword(
        email: widget.email,
        password: widget.password,
        firstName: widget.firstName,
        lastName: widget.lastName,
        licensePlate: _plateController.text.trim().toUpperCase(),
      );

      // Sukces! Cofamy wszystko do początku (AuthGate i tak nas przeniesie na Home)
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd rejestracji: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Krok 2/2: Twój Pojazd')),
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
            
            // POLE NUMERU REJESTRACYJNEGO
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
            
            const SizedBox(height: 32),
            
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _finishRegistration,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Text('ZAKOŃCZ I ZAREJESTRUJ', style: TextStyle(fontSize: 18)),
                  ),
          ],
        ),
      ),
    );
  }
}