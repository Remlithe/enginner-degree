// lib/screens/license_plate_screen.dart
import 'package:flutter/material.dart';
import 'payment_setup_screen.dart';
import '../widgets/license_plate_input.dart';

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

  // Funkcja sprawdzająca format rejestracji
  bool _isPlateValid(String plate) {
    // 1. Usuwamy spacje i myślniki, zamieniamy na duże litery
    String cleanPlate = plate.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    
    // 2. Sprawdzenie długości (Polskie tablice mają od 5 do 8 znaków, np. GDA 12345 to 8, W 12345 to 6)
    if (cleanPlate.length < 7 || cleanPlate.length > 9) {
      return false;
    }

    // 3. OCHRONA PRZED "PPPPPPP": Musi być przynajmniej jedna cyfra
    // (Większość tablic, nawet indywidualnych, ma cyfry, albo chcemy unikać spamu)
    bool hasDigit = cleanPlate.contains(RegExp(r'[0-9]'));
    if (!hasDigit) {
      return false; 
    }

    // 4. Sprawdzenie struktury:
    // - Musi się zaczynać od 1-3 liter (Wyróżnik miejsca)
    // - Potem następuje ciąg znaków (cyfry lub litery)
    final plateRegex = RegExp(r'^[A-Z]{1,3}[A-Z0-9]{3,6}$');
    
    return plateRegex.hasMatch(cleanPlate);
  }

  void _goToPaymentStep() {
    String plate = _plateController.text.trim().toUpperCase();

    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj numer rejestracyjny.')),
      );
      return;
    }

    // WALIDACJA FORMATU
    if (!_isPlateValid(plate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Błędny format rejestracji. Poprawny np: PO 12345, WA 98765'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Przechodzimy dalej z poprawnym numerem
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => PaymentSetupScreen(
        firstName: widget.firstName,
        lastName: widget.lastName,
        email: widget.email,
        password: widget.password,
        licensePlate: plate, // Przekazujemy sformatowany numer
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
              'Wprowadź numer rejestracyjny (format polski).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            
            LicensePlateInput(controller: _plateController),
            
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