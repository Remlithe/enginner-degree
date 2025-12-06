// lib/screens/registration_screen.dart
import 'package:flutter/material.dart';
import 'license_plate_screen.dart'; // <--- Zaraz utworzymy ten plik

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _goToNextStep() {
    // Prosta walidacja, czy pola nie są puste
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || 
        _firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wypełnij wszystkie pola, aby przejść dalej.')),
      );
      return;
    }

    // NAWIGACJA DO EKRANU 2 (PRZEKAZUJEMY DANE)
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => LicensePlateScreen(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Krok 1/3: Dane Osobowe')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView( // Dodane, żeby klawiatura nie zasłaniała
          child: Column(
            children: [
              TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'Imię')),
              const SizedBox(height: 16),
              TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Nazwisko')),
              const SizedBox(height: 16),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Hasło'), obscureText: true),
              const SizedBox(height: 32),
              
              // PRZYCISK "DALEJ"
              ElevatedButton(
                onPressed: _goToNextStep,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('DALEJ', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}