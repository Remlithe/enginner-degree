// lib/screens/registration_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'license_plate_screen.dart'; 

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
  
  // NOWE POLE: Potwierdzenie hasła
  final TextEditingController _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService(); // Instancja serwisu
  bool _isLoading = false;

  // Funkcja walidująca email za pomocą wyrażenia regularnego (Regex)
  bool _isEmailValid(String email) {
    // Prosty, ale skuteczny wzorzec: coś@coś.coś
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  void _goToNextStep() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    // 1. Czy wszystko wypełnione?
    if (email.isEmpty || password.isEmpty || 
        _firstNameController.text.isEmpty || _lastNameController.text.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wypełnij wszystkie pola.')),
      );
      return;
    }

    if (!_isEmailValid(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj poprawny adres email.')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasła nie są identyczne.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasło musi mieć co najmniej 6 znaków.')),
      );
      return;
    }

    // 2. Czy email jest poprawny?
    if (!_isEmailValid(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj poprawny adres email (np. jan@example.com).')),
      );
      return;
    }

    // 4. Czy hasło jest wystarczająco silne? (opcjonalnie min. 6 znaków)
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasło musi mieć co najmniej 6 znaków.')),
      );
      return;
    }
    setState(() {
      _isLoading = true; // Włączamy kręciołek
    });

    bool emailExists = await _authService.checkEmailExists(email);

    setState(() {
      _isLoading = false; // Wyłączamy kręciołek
    });

    if (emailExists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ten adres email jest już zajęty! Zaloguj się lub użyj innego.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return; // Stop, nie idziemy dalej
    }
    // Przechodzimy dalej
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => LicensePlateScreen(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: email,
        password: password,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Krok 1/3: Dane Osobowe')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView( 
          child: Column(
            children: [
              TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'Imię')),
              const SizedBox(height: 16),
              TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Nazwisko')),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController, 
                decoration: const InputDecoration(labelText: 'Email', hintText: 'przyklad@email.com'), 
                keyboardType: TextInputType.emailAddress
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController, 
                decoration: const InputDecoration(labelText: 'Hasło'), 
                obscureText: true
              ),
              const SizedBox(height: 16),
              
              // NOWY INPUT
              TextField(
                controller: _confirmPasswordController, 
                decoration: const InputDecoration(labelText: 'Potwierdź hasło'), 
                obscureText: true
              ),
              
              const SizedBox(height: 32),
              
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