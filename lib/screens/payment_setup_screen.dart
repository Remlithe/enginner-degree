import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
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
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the card name with the user's name
    _nameController.text = '${widget.firstName} ${widget.lastName}';
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Format card number input with spaces after every 4 digits
  void _formatCardNumber() {
    final text = _cardNumberController.text.replaceAll(' ', '');
    if (text.length > 16) {
      _cardNumberController.text = text.substring(0, 16);
      return;
    }
    
    final newString = <String>[];
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        newString.add(' ');
      }
      newString.add(text[i]);
    }
    
    _cardNumberController.value = TextEditingValue(
      text: newString.join(),
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }

  // Format expiry date with slash
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
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() => _isLoading = true);

  try {
    // For now, we'll use a test payment method instead of creating a real one
    const testPaymentMethodId = 'pm_card_visa';
    
    // Get the last 4 digits of the card number
    final cardNumber = _cardNumberController.text.replaceAll(' ', '');
    final last4 = cardNumber.substring(cardNumber.length - 4);
    
    // Call your Firebase function to create a Stripe customer
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createCustomer');
    final result = await callable.call({
      'email': widget.email,
      'name': '${widget.firstName} ${widget.lastName}',
      'payment_method_id': testPaymentMethodId,
    });
    
    final stripeCustomerId = result.data['customerId'];
    final paymentMethodId = result.data['paymentMethodId']; // Get the actual payment method ID from response
    
    // Register user with Stripe customer ID and card info
    final userModel = await _authService.registerWithEmailPassword(
      email: widget.email,
      password: widget.password,
      firstName: widget.firstName,
      lastName: widget.lastName,
      licensePlate: widget.licensePlate,
      stripeCustomerId: stripeCustomerId,
      paymentMethodId: paymentMethodId, // Use the payment method ID from the function response
      cardLast4: last4,
    );

    if (mounted && userModel != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful!')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 3/3: Add Payment Card')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Card Icon and Header
                const Icon(Icons.credit_card, size: 60, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  "Payment Information",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Your payment information is securely processed",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                
                // Card Number Field
                TextFormField(
                  controller: _cardNumberController,
                  decoration: InputDecoration(
                    labelText: 'Card Number',
                    hintText: '4242 4242 4242 4242',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _formatCardNumber(),
                  validator: (value) {
                    if (value == null || value.replaceAll(' ', '').length < 16) {
                      return 'Please enter a valid 16-digit card number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Row for Expiry and CVV
                Row(
                  children: [
                    // Expiry Date Field
                    Expanded(
                      child: TextFormField(
                        controller: _expiryController,
                        decoration: InputDecoration(
                          labelText: 'Expiry Date',
                          hintText: 'MM/YY',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.date_range),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _formatExpiry(),
                        validator: (value) {
                          if (value == null || value.replaceAll('/', '').length < 4) {
                            return 'Valid date required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // CVV Field
                    Expanded(
                      child: TextFormField(
                        controller: _cvvController,
                        decoration: InputDecoration(
                          labelText: 'CVV',
                          hintText: '123',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.security),
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        validator: (value) {
                          if (value == null || value.length < 3) {
                            return 'Valid CVV required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Name on Card Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name on Card',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the name on card';
                    }
                    return null;
                  },
                ),
                
                // Test Card Hint - Remove this in production
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    'For testing, use: 4242 4242 4242 4242, any future date, any 3-digit CVV',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const Spacer(),
                
                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'COMPLETE REGISTRATION',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
