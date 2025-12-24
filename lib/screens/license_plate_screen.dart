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
  
  String? _plateError;

  bool _isPlateValid(String plate) {
    String cleanPlate = plate.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    if (cleanPlate.length < 7 || cleanPlate.length > 9) return false;
    bool hasDigit = cleanPlate.contains(RegExp(r'[0-9]'));
    if (!hasDigit) return false;
    final plateRegex = RegExp(r'^[A-Z]{1,3}[A-Z0-9]{3,6}$');
    return plateRegex.hasMatch(cleanPlate);
  }

  void _goToPaymentStep() {
    setState(() {
      _plateError = null;
    });

    String plate = _plateController.text.trim().toUpperCase();

    if (plate.isEmpty) {
      setState(() => _plateError = "Podaj numer rejestracyjny");
      return;
    }

    if (!_isPlateValid(plate)) {
      setState(() => _plateError = "Błędny format (np. PO 12345)");
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => PaymentSetupScreen(
        firstName: widget.firstName,
        lastName: widget.lastName,
        email: widget.email,
        password: widget.password,
        licensePlate: plate,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // Blokada skalowania
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: 0.66,
                    backgroundColor: Colors.grey[200],
                    color: const Color(0xFF007AFF),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 10),
                  const Text("Krok 2 z 3", textAlign: TextAlign.right, style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  // Padding manualny
                  padding: EdgeInsets.only(
                    left: 24.0, 
                    right: 24.0, 
                    bottom: bottomPadding + 20
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.directions_car, size: 60, color: Color(0xFF007AFF)),
                      const SizedBox(height: 20),
                      const Text("Twój pojazd", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text("Wpisz numer rejestracyjny, aby kamery mogły rozpoznać Twój samochód.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      
                      const SizedBox(height: 40),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _plateError != null ? Colors.red : Colors.grey.shade300,
                          ),
                        ),
                        child: LicensePlateInput(controller: _plateController),
                      ),

                      if (_plateError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                          child: Text(
                            _plateError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                height: 55,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _goToPaymentStep,
                  child: const Text("DALEJ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}