import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/auth_service.dart';

class PaymentSetupScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String licensePlate;

  const PaymentSetupScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.licensePlate,
  });

  @override
  State<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends State<PaymentSetupScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  final _cardFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();
  final _nameFocus = FocusNode();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController.text = '${widget.firstName} ${widget.lastName}';
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _cardFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _formatCardNumber() {
    final text = _cardNumberController.text.replaceAll(' ', '');
    if (text.length > 16) {
      _cardNumberController.text = text.substring(0, 16);
      return;
    }
    final newString = <String>[];
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) newString.add(' ');
      newString.add(text[i]);
    }
    _cardNumberController.value = TextEditingValue(
      text: newString.join(),
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }

  void _formatExpiry() {
    final text = _expiryController.text.replaceAll('/', '');
    if (text.length > 4) {
      _expiryController.text = text.substring(0, 4);
      return;
    }
    if (text.length > 2) {
      _expiryController.value = TextEditingValue(
        text: '${text.substring(0, 2)}/${text.substring(2)}',
        selection: TextSelection.collapsed(offset: text.length + 1),
      );
    } else {
      _expiryController.text = text;
    }
  }

  Future<void> _completeRegistration() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      const testPaymentMethodId = 'pm_card_visa';
      final cardNumber = _cardNumberController.text.replaceAll(' ', '');
      final last4 = cardNumber.substring(cardNumber.length - 4);
      
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createCustomer');
      final result = await callable.call({
        'email': widget.email,
        'name': '${widget.firstName} ${widget.lastName}',
        'payment_method_id': testPaymentMethodId,
      });
      
      final stripeCustomerId = result.data['customerId'];
      final paymentMethodId = result.data['paymentMethodId'];
      
      final userModel = await _authService.registerWithEmailPassword(
        email: widget.email,
        password: widget.password,
        firstName: widget.firstName,
        lastName: widget.lastName,
        licensePlate: widget.licensePlate,
        stripeCustomerId: stripeCustomerId,
        paymentMethodId: paymentMethodId,
        cardLast4: last4,
      );

      if (mounted && userModel != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejestracja pomyślna!')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Błąd rejestracji: ${e.toString()}";
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
      resizeToAvoidBottomInset: false, // Blokada skalowania
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // GÓRA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: 1.0,
                    backgroundColor: Colors.grey[200],
                    color: const Color(0xFF007AFF),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 10),
                  const Text("Krok 3 z 3", textAlign: TextAlign.right, style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),

            // ŚRODEK
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  // Padding manualny
                  padding: EdgeInsets.only(
                    left: 24.0, 
                    right: 24.0, 
                    bottom: bottomPadding + 20
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.credit_card, size: 60, color: Color(0xFF007AFF)),
                        const SizedBox(height: 20),
                        const Text("Metoda płatności", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 40),
                        
                        _buildInput(_cardNumberController, 'Numer Karty', Icons.credit_card, 
                          type: TextInputType.number, 
                          onChanged: (v) => _formatCardNumber(),
                          validator: (v) => (v == null || v.replaceAll(' ', '').length < 16) ? 'Nieprawidłowy numer karty' : null,
                          focusNode: _cardFocus,
                          nextFocus: _expiryFocus,
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildInput(_expiryController, 'Data (MM/YY)', Icons.calendar_today,
                                type: TextInputType.number,
                                onChanged: (v) => _formatExpiry(),
                                validator: (v) => (v == null || v.length < 5) ? 'Błąd daty' : null,
                                focusNode: _expiryFocus,
                                nextFocus: _cvvFocus,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInput(_cvvController, 'CVV', Icons.lock,
                                type: TextInputType.number,
                                isObscure: true,
                                validator: (v) => (v == null || v.length < 3) ? 'Błąd CVV' : null,
                                focusNode: _cvvFocus,
                                nextFocus: _nameFocus,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInput(_nameController, 'Imię i nazwisko na karcie', Icons.person,
                          validator: (v) => (v == null || v.isEmpty) ? 'Pole wymagane' : null,
                          focusNode: _nameFocus,
                          isLast: true,
                          onSubmitted: (_) => _completeRegistration(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // DÓŁ
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  SizedBox(
                    height: 55,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _completeRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('ZAREJESTRUJ SIĘ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, {
    TextInputType? type, 
    bool isObscure = false, 
    Function(String)? onChanged,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    bool isLast = false,
    Function(String)? onSubmitted
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: isObscure,
      focusNode: focusNode,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: onSubmitted ?? (_) {
        if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        }
      },
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}