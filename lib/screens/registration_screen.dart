import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'license_plate_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool _isEmailValid(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,6}$');
    return emailRegex.hasMatch(email);
  }

  bool _hasDigits(String text) {
    return RegExp(r'[0-9]').hasMatch(text);
  }

  void _goToNextStep() async {
    setState(() {
      _firstNameError = null;
      _lastNameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    bool isValid = true;

    if (firstName.isEmpty) {
      setState(() => _firstNameError = "Podaj imię");
      isValid = false;
    } else if (_hasDigits(firstName)) {
      setState(() => _firstNameError = "Bez cyfr");
      isValid = false;
    }

    if (lastName.isEmpty) {
      setState(() => _lastNameError = "Podaj nazwisko");
      isValid = false;
    } else if (_hasDigits(lastName)) {
      setState(() => _lastNameError = "Bez cyfr");
      isValid = false;
    }

    if (email.isEmpty) {
      setState(() => _emailError = "Podaj email");
      isValid = false;
    } else if (!_isEmailValid(email)) {
      setState(() => _emailError = "Zły format");
      isValid = false;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = "Podaj hasło");
      isValid = false;
    } else if (password.length < 6) {
      setState(() => _passwordError = "Min. 6 znaków");
      isValid = false;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = "Powtórz hasło");
      isValid = false;
    } else if (password != confirmPassword) {
      setState(() => _confirmPasswordError = "Różne hasła");
      isValid = false;
    }

    if (!isValid) return;

    setState(() => _isLoading = true);
    bool emailExists = await _authService.checkEmailExists(email);
    setState(() => _isLoading = false);

    if (emailExists) {
      setState(() => _emailError = "Email zajęty");
      return;
    }

    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => LicensePlateScreen(
          firstName: firstName,
          lastName: lastName,
          email: email,
          password: password,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // Blokada, żeby guzik nie skakał
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // GÓRA: PROGRESS BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: 0.33,
                    backgroundColor: Colors.grey[200],
                    color: const Color(0xFF007AFF),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 10),
                  const Text("Krok 1 z 3", textAlign: TextAlign.right, style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),

            // ŚRODEK: TREŚĆ
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24.0, 
                    right: 24.0, 
                    bottom: bottomPadding + 20 // Padding na klawiaturę
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text("Dane osobowe", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 30),

                      _buildInput(_firstNameController, "Imię", Icons.person, 
                        errorText: _firstNameError, 
                        focusNode: _firstNameFocus, 
                        nextFocus: _lastNameFocus
                      ),
                      const SizedBox(height: 16),
                      
                      _buildInput(_lastNameController, "Nazwisko", Icons.person, 
                        errorText: _lastNameError,
                        focusNode: _lastNameFocus,
                        nextFocus: _emailFocus
                      ),
                      const SizedBox(height: 16),
                      
                      _buildInput(_emailController, "Email", Icons.email, 
                        type: TextInputType.emailAddress, 
                        errorText: _emailError,
                        focusNode: _emailFocus,
                        nextFocus: _passwordFocus
                      ),
                      const SizedBox(height: 16),
                      
                      _buildInput(_passwordController, "Hasło", Icons.lock, 
                        isObscure: true, 
                        errorText: _passwordError,
                        focusNode: _passwordFocus,
                        nextFocus: _confirmFocus
                      ),
                      const SizedBox(height: 16),
                      
                      _buildInput(_confirmPasswordController, "Potwierdź hasło", Icons.lock, 
                        isObscure: true, 
                        errorText: _confirmPasswordError,
                        focusNode: _confirmFocus,
                        isLast: true, 
                        onSubmitted: (_) => _goToNextStep(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // DÓŁ: GUZIK
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
                  onPressed: _isLoading ? null : _goToNextStep,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("DALEJ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
      String? errorText,
      FocusNode? focusNode,
      FocusNode? nextFocus,
      bool isLast = false,
      Function(String)? onSubmitted,
    }) {
    
    // Używamy naszego pomocniczego widgetu, który sam dba o scrollowanie
    return _AutoScrollWhenFocused(
      focusNode: focusNode!,
      child: TextField(
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
          errorText: errorText, 
        ),
      ),
    );
  }
}

// --- KLASA POMOCNICZA DO AUTOMATYCZNEGO SCROLLOWANIA ---
class _AutoScrollWhenFocused extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;

  const _AutoScrollWhenFocused({required this.focusNode, required this.child});

  @override
  State<_AutoScrollWhenFocused> createState() => _AutoScrollWhenFocusedState();
}

class _AutoScrollWhenFocusedState extends State<_AutoScrollWhenFocused> {
  @override
  void initState() {
    super.initState();
    // Nasłuchujemy zmian fokusu
    widget.focusNode.addListener(_ensureVisible);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_ensureVisible);
    super.dispose();
  }

  void _ensureVisible() {
    // Jeśli pole dostało focus...
    if (widget.focusNode.hasFocus) {
      // Czekamy chwilę, aż klawiatura zacznie wychodzić i padding się zaktualizuje
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // Magiczna metoda Fluttera: "Przewiń tak, żeby ten widget był widoczny"
          Scrollable.ensureVisible(
            context,
            alignment: 0.5, // 0.5 oznacza: spróbuj ustawić ten element na środku ekranu
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}