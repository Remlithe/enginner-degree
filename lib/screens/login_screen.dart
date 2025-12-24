import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'registration_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Focus nodes
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // Zmienne na błędy
  String? _emailError;    // Błąd formatu (pod inputem)
  String? _generalError;  // Błąd logowania (nad inputami)

  final _authService = AuthService(); 
  bool _isLoading = false;

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isEmailValid(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,6}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _login() async {
    // 1. Reset błędów przed nową próbą
    setState(() {
      _emailError = null;
      _generalError = null;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    // 2. Walidacja lokalna (puste pola i format emaila)
    bool isValid = true;

    if (email.isEmpty) {
      setState(() => _emailError = "Podaj email");
      isValid = false;
    } else if (!_isEmailValid(email)) {
      setState(() => _emailError = "Niepoprawny format emaila");
      isValid = false;
    }

    if (password.isEmpty) {
      // Hasło nie wymaga walidacji formatu przy logowaniu, tylko czy jest wpisane
      // Możemy wyświetlić ogólny błąd jeśli puste, lub snackbar. 
      // Tutaj założymy, że puste hasło to błąd ogólny lub po prostu blokada.
      // Dla lepszego UX przy logowaniu często waliduje się tylko czy pola są pełne.
      setState(() => _generalError = "Uzupełnij wszystkie dane");
      return; 
    }

    if (!isValid) return; // Jeśli format emaila zły, nie pytamy Firebase

    setState(() => _isLoading = true);

    try {
      final userModel = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      if (userModel != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        throw Exception("Błąd logowania.");
      }
    } catch (e) {
      if (mounted) {
        // Tutaj łapiemy błędy z Firebase (np. user-not-found, wrong-password)
        // I wyświetlamy je jako jeden ogólny błąd NAD inputami
        setState(() {
          _generalError = "Błędny email lub hasło";
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // Guzik i layout stabilny
      body: SafeArea(
        child: Column(
          children: [
            // --- GÓRA I ŚRODEK (Przewijalne) ---
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24.0, 
                    right: 24.0, 
                    bottom: bottomPadding + 20
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.local_parking, size: 80, color: Color(0xFF007AFF)),
                      const SizedBox(height: 20),
                      const Text(
                        "ParkCheck",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 30),

                      // --- OGÓLNY BŁĄD (Nad inputami) ---
                      if (_generalError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200)
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _generalError!,
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      _buildInput(
                        _emailController, "Email", Icons.email, 
                        type: TextInputType.emailAddress,
                        focusNode: _emailFocus,
                        nextFocus: _passwordFocus,
                        errorText: _emailError // Błąd formatu pod polem
                      ),
                      const SizedBox(height: 16),
                      
                      _buildInput(
                        _passwordController, "Hasło", Icons.lock, 
                        isObscure: true,
                        focusNode: _passwordFocus,
                        isLast: true, 
                        onSubmitted: (_) => _login(),
                        // Hasło przy logowaniu zazwyczaj nie pokazuje błędów walidacji pod spodem,
                        // błąd hasła wpada do _generalError.
                      ),

                      const SizedBox(height: 20),

                      // Link do rejestracji
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                          );
                        },
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Roboto'),
                            children: [
                              TextSpan(text: "Nie masz konta? "),
                              TextSpan(
                                text: "Zarejestruj się", 
                                style: TextStyle(
                                  color: Color(0xFF007AFF),
                                  fontWeight: FontWeight.bold, 
                                  decoration: TextDecoration.underline
                                )
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- DÓŁ: BUTTON (Sticky) ---
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
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("ZALOGUJ SIĘ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl, 
    String label, 
    IconData icon, 
    {
      bool isObscure = false, 
      TextInputType? type,
      FocusNode? focusNode,
      FocusNode? nextFocus,
      bool isLast = false,
      Function(String)? onSubmitted,
      String? errorText, // Dodany parametr błędu
    }) {
    return TextField(
      controller: ctrl,
      obscureText: isObscure,
      keyboardType: type,
      focusNode: focusNode,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onSubmitted: onSubmitted ?? (_) {
        if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
        errorText: errorText, // Wyświetlanie błędu pod polem
      ),
    );
  }
}