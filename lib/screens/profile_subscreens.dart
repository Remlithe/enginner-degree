// lib/screens/profile_subscreens.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../widgets/license_plate_input.dart'; // Używamy Twojego nowego, ładnego widgetu

// --- WSPÓLNY STYL DLA EKRANÓW ---
class BaseEditScreen extends StatelessWidget {
  final String title;
  final Widget body;
  final VoidCallback? onSave;
  final String buttonText;

  const BaseEditScreen({
    super.key,
    required this.title,
    required this.body,
    this.onSave,
    this.buttonText = "ZAPISZ",
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.black, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(child: SingleChildScrollView(child: body)),
              if (onSave != null)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 1. EKRAN DANE OSOBOWE (Z Walidacją)
class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});
  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); 
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _firstNameCtrl.text = data['firstName'] ?? '';
        _lastNameCtrl.text = data['lastName'] ?? '';
        _emailCtrl.text = user?.email ?? '';
      });
    }
  }

  void _saveData() async {
    // --- WALIDACJA (Tak samo jak przy rejestracji) ---
    if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Imię i nazwisko nie mogą być puste.")),
      );
      return;
    }
    // -------------------------------------------------

    try {
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dane zapisane!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Błąd zapisu: $e")));
      }
    }
  }

  // Funkcja resetu hasła (bez zmian)
  void _sendPasswordReset() async {
    if (user?.email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Sprawdź skrzynkę"),
            content: Text("Wysłaliśmy link do zmiany hasła na adres:\n${user!.email}"),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Błąd: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseEditScreen(
      title: "Dane osobowe",
      onSave: _saveData,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("Imię"),
          _buildInput(_firstNameCtrl),
          const SizedBox(height: 20),
          _buildLabel("Nazwisko"),
          _buildInput(_lastNameCtrl),
          const SizedBox(height: 20),
          
          _buildLabel("Email (Login)"),
          _buildInput(_emailCtrl, enabled: false),
          const SizedBox(height: 20),

          _buildLabel("Hasło"),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("• • • • • • • •", style: TextStyle(fontSize: 20, letterSpacing: 2, color: Colors.grey)),
                TextButton(
                  onPressed: _sendPasswordReset,
                  child: const Text("ZMIEŃ", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          const Text("Kliknij 'ZMIEŃ', aby otrzymać link do ustawienia nowego hasła.", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// 2. EKRAN DANE POJAZDU (Z Walidacją Rejestracji)
class VehicleDataScreen extends StatefulWidget {
  const VehicleDataScreen({super.key});
  @override
  State<VehicleDataScreen> createState() => _VehicleDataScreenState();
}

class _VehicleDataScreenState extends State<VehicleDataScreen> {
  final _plateCtrl = TextEditingController();
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
    if (doc.exists) {
      setState(() {
        _plateCtrl.text = doc.data()!['licensePlate'] ?? '';
      });
    }
  }

  // --- WALIDACJA (Skopiowana z license_plate_screen.dart) ---
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
  // ---------------------------------------------------------

  void _saveData() async {
    String plate = _plateCtrl.text.trim().toUpperCase();

    // 1. Sprawdź czy puste
    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Numer rejestracyjny jest wymagany.")),
      );
      return;
    }

    // 2. Sprawdź format (Polska/UE)
    if (!_isPlateValid(plate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Błędny format rejestracji. Poprawny np: PO 12345'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // 3. Zapisz jeśli ok
    await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
      'licensePlate': plate,
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rejestracja zaktualizowana!")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseEditScreen(
      title: "Dane pojazdu",
      onSave: _saveData,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("Numer rejestracyjny"),
          const SizedBox(height: 10),
          // Używamy Twojego ładnego widgetu tablicy
          LicensePlateInput(controller: _plateCtrl),
        ],
      ),
    );
  }
}

// 3. EKRAN DANE KARTY (Bez zmian)
class CardDataScreen extends StatelessWidget {
  const CardDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return BaseEditScreen(
      title: "Dane karty",
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final last4 = data['cardLast4'] ?? '****';

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
            ),
            child: Row(
              children: [
                const Icon(Icons.credit_card, size: 40, color: Colors.blue),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Twoja karta", style: TextStyle(color: Colors.grey)),
                    Text("**** **** **** $last4", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 4. EKRAN ZGŁOŚ PROBLEM (Bez zmian)
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});
  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _msgCtrl = TextEditingController();

  void _sendReport() {
    if (_msgCtrl.text.isEmpty) return;
    
    FirebaseFirestore.instance.collection('reports').add({
      'uid': FirebaseAuth.instance.currentUser?.uid,
      'message': _msgCtrl.text,
      'date': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Zgłoszenie wysłane!")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BaseEditScreen(
      title: "Zgłoś problem",
      buttonText: "WYŚLIJ",
      onSave: _sendReport,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("Opisz swój problem"),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _msgCtrl,
              maxLines: 6,
              decoration: const InputDecoration.collapsed(hintText: "Wpisz treść wiadomości..."),
            ),
          ),
        ],
      ),
    );
  }
}

// Helpery UI
Widget _buildLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(text, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
  );
}

Widget _buildInput(TextEditingController ctrl, {bool enabled = true}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: BoxDecoration(
      color: enabled ? Colors.white : Colors.grey[200],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: TextField(
      controller: ctrl,
      enabled: enabled,
      decoration: const InputDecoration(border: InputBorder.none),
    ),
  );
}