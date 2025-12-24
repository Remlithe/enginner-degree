import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:parkcheck/widgets/auth_gate.dart';
import 'package:parkcheck/firebase_options.dart';
import 'package:flutter_stripe/flutter_stripe.dart';




void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // First initialize Firebase - this rarely fails
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
    
    // Then initialize Stripe with error handling
    try {
    Stripe.publishableKey = 'pk_test_51SZtQM6TqOz44N4yRz4j6AiysVbnL3NjnCgm2zXtNSTlKYVaGkChUWPixVGmrKpEwNR5rG6A7S1GVnrd7O6boe5B004IwZL1aW';
    print('Stripe publishable key set successfully');
    
  } catch (e) {
    print('Failed to initialize Stripe: $e');
  }
  
    // await testFirebaseFunction();
    // await testStripeInit();
    // Run the app
    runApp(const MainApp());
  } catch (e) {
    print('Failed to initialize app: $e');
    // Show an error screen if initialization completely fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Failed to initialize: $e', 
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ));
  }
  
}
// Future<void> testFirebaseFunction() async {
//   try {
//     print('Testing Firebase function...');
    
//     final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createCustomer');
//     final result = await callable.call({
//       'email': 'test@example.com',
//       'name': 'Test User',
//       'payment_method_id': 'pm_card_visa', // This is a test payment method ID that Stripe accepts
//     });
    
//     print('Function called successfully!');
//     print('Response: ${result.data}');
    
//     // If this works, your Firebase function is working correctly!
//   } catch (e) {
//     print('Error calling Firebase function: $e');
//   }
// }

// Future<void> testStripeInit() async {
//   try {
//     print('Testing Stripe initialization...');
    
//     // Set publishable key
//     if (Stripe.publishableKey.isEmpty) {
//       Stripe.publishableKey = 'pk_test_51SZtQM6TqOz44N4yRz4j6AiysVbnL3NjnCgm2zXtNSTlKYVaGkChUWPixVGmrKpEwNR5rG6A7S1GVnrd7O6boe5B004IwZL1aW';
//     }
    
//     // Instead of creating a payment method, let's check if we can access Stripe instance
//     // This is a better way to test if Stripe SDK is initialized
//     final instance = Stripe.instance;
//     print('Stripe instance accessed successfully: ${instance.hashCode}');
    
//     // Try a simpler Stripe API call - get publishable key
//     final key = Stripe.publishableKey;
//     print('Stripe publishable key: $key');
    
//     print('Stripe SDK initialized successfully!');
//   } catch (e) {
//     print('Error initializing Stripe: $e');
    
//     // Add more detailed error info
//     if (e is PlatformException) {
//       print('Error code: ${e.code}');
//       print('Error message: ${e.message}');
//       print('Error details: ${e.details}');
//     }
//   }
// }

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkCheck Klient',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthGate(),
    );
  }
  
}
