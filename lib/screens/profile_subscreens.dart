// lib/screens/profile_subscreens.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/license_plate_input.dart';

// --- WSPÓLNY STYL DLA EKRANÓW ---
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
    // Pobieramy wysokość klawiatury
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      // 1. To blokuje przesuwanie się całego układu (w tym guzika) do góry
      resizeToAvoidBottomInset: false, 
      
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                // 2. Dodajemy padding dynamiczny na dole.
                // Dzięki temu treść można przewinąć nad klawiaturę, 
                // mimo że Scaffold się nie zmniejszył.
                padding: EdgeInsets.only(
                  left: 24.0, 
                  right: 24.0, 
                  top: 24.0, 
                  bottom: bottomPadding + 24.0 // Klawiatura + margines
                ),
                child: body,
              ),
            ),
            
            // Guzik jest poza ScrollView, więc zawsze trzyma się dołu ekranu
            if (onSave != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  // Opcjonalnie: cień, żeby oddzielić guzik od treści
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    )
                  ],
                ),
                child: SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 1. EKRAN DANE OSOBOWE
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
    if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Imię i nazwisko nie mogą być puste.")),
      );
      return;
    }

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          // Zmienione na styl z LoginScreen (Input w stylu Outline z ikoną)
          _buildInput(_firstNameCtrl, "Imię", Icons.person),
          const SizedBox(height: 16),
          
          _buildInput(_lastNameCtrl, "Nazwisko", Icons.person),
          const SizedBox(height: 16),
          
          _buildInput(_emailCtrl, "Email (Login)", Icons.email, enabled: false),
          const SizedBox(height: 24),

          // Sekcja hasła (customowa, ale dopasowana stylem obramowania)
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400), // Kolor obramowania jak w inputach (domyślny Fluttera)
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: Icon(Icons.lock, color: Colors.grey), // Ikona kłódki
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Hasło", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text("• • • • • • • •", style: TextStyle(fontSize: 16, letterSpacing: 2)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _sendPasswordReset,
                  child: const Text("ZMIEŃ", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Kliknij 'ZMIEŃ', aby otrzymać link do resetowania hasła.", 
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey)
          ),
        ],
      ),
    );
  }
}

// 2. EKRAN DANE POJAZDU
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

  bool _isPlateValid(String plate) {
    String cleanPlate = plate.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    if (cleanPlate.length < 7 || cleanPlate.length > 9) return false;
    bool hasDigit = cleanPlate.contains(RegExp(r'[0-9]'));
    if (!hasDigit) return false; 
    final plateRegex = RegExp(r'^[A-Z]{1,3}[A-Z0-9]{3,6}$');
    return plateRegex.hasMatch(cleanPlate);
  }

  void _saveData() async {
    String plate = _plateCtrl.text.trim().toUpperCase();

    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Numer rejestracyjny jest wymagany.")));
      return;
    }
    if (!_isPlateValid(plate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Błędny format rejestracji. Poprawny np: PO 12345'), duration: Duration(seconds: 4)));
      return;
    }

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
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text("NUMER REJESTRACYJNY", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          LicensePlateInput(controller: _plateCtrl),
        ],
      ),
    );
  }
}

// 3. EKRAN DANE KARTY
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
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.credit_card, size: 30, color: Color(0xFF007AFF)),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Twoja karta", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("**** **** **** $last4", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
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

// 4. EKRAN ZGŁOŚ PROBLEM
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
      buttonText: "WYŚLIJ ZGŁOSZENIE",
      onSave: _sendReport,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text("OPISZ SWÓJ PROBLEM", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          TextField(
            controller: _msgCtrl,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: "Wpisz tutaj treść wiadomości...",
              filled: true,
              fillColor: Colors.grey[50], // Styl tła jak w login
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPERY UI (STYL LOGIN SCREEN) ---

// Teraz ta funkcja wygląda DOKŁADNIE jak w LoginScreen
Widget _buildInput(TextEditingController ctrl, String label, IconData icon, {bool enabled = true}) {
  return TextField(
    controller: ctrl,
    enabled: enabled,
    decoration: InputDecoration(
      labelText: label, // Etykieta w środku
      prefixIcon: Icon(icon), // Ikona z lewej
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), // Zaokrąglenie 12
      filled: true,
      fillColor: enabled ? Colors.grey[50] : Colors.grey[200], // Tło
    ),
  );
}