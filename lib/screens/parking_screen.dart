import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
// Ukrywamy 'Card' ze Stripe, żeby nie gryzło się z Flutterem
import 'package:flutter_stripe/flutter_stripe.dart' hide Card; 
import '../models/user_model.dart';
import '../models/parking_area_model.dart';
import '../services/parking_service.dart';

class ParkingScreen extends StatefulWidget {
  final VoidCallback? onFindParking;

  const ParkingScreen({super.key, this.onFindParking});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ParkingService _parkingService = ParkingService();

  // --- STANY ---
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isLoadingAction = false;
  
  // --- SESJA PARKOWANIA ---
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  String? _activeSessionId;
  ParkingAreaModel? _activeParking;
  DateTime? _startTime;
  Timer? _timer;
  String _elapsedTimeStr = "00:00:00";
  double _currentCost = 0.0;
  String _paymentStatusText = "";

  String _myLicensePlate = "Ładowanie...";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _determinePosition(); 
    _restoreActiveSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  // --- DEBUG: PRZEWIJANIE CZASU ---
  void _debugAdd15Minutes() {
    if (_startTime != null) {
      setState(() {
        _startTime = _startTime!.subtract(const Duration(minutes: 15));
      });
      // Wymuś odświeżenie licznika natychmiast
      _updateTimerLogic();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Dodano 15 minut do czasu postoju (Debug)"), 
        duration: Duration(seconds: 1)
      ));
    }
  }

  // 1. Pobierz tablicę
  void _fetchUserData() async {
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    if (mounted && doc.exists) {
      setState(() {
        _myLicensePlate = doc.data()?['licensePlate'] ?? "BRAK TABLICY";
      });
    }
  }

  // 2. Lokalizacja
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if(mounted) setState(() => _isLoadingLocation = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if(mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    try {
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentPosition = lastKnown;
          _isLoadingLocation = false;
        });
      }

      Position current = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = current;
          _isLoadingLocation = false;
        });
      }

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      });

    } catch (e) {
      print("Błąd GPS: $e");
      if(mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // 3. Przywracanie sesji
  void _restoreActiveSession() async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final q = await FirebaseFirestore.instance.collection('parking_sessions')
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      final sessionDoc = q.docs.first;
      final data = sessionDoc.data();
      
      final parkingDoc = await FirebaseFirestore.instance.collection('parking_spots').doc(data['parkingId']).get();
      if (parkingDoc.exists) {
        final parkingObj = ParkingAreaModel.fromFirestore(parkingDoc.data()!, parkingDoc.id);
        
        setState(() {
          _activeSessionId = sessionDoc.id;
          _activeParking = parkingObj;
          _startTime = (data['startTime'] as Timestamp).toDate();
        });
        _startTimer();
        _listenToSessionChanges(sessionDoc.id);
      }
    }
  }

  // 4. Start Parkowania
  void _startParkingSession(ParkingAreaModel parking) async {
    if (_myLicensePlate == "BRAK TABLICY") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uzupełnij tablicę w profilu!")));
      return;
    }

    setState(() => _isLoadingAction = true);

    try {
      final ref = await FirebaseFirestore.instance.collection('parking_sessions').add({
        'parkingId': parking.id,
        'parkingName': parking.name,
        'ownerId': parking.ownerUid,
        'driverId': currentUser!.uid,
        'licensePlate': _myLicensePlate,
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
        'cost': 0.0,
      });

      setState(() {
        _activeSessionId = ref.id;
        _activeParking = parking;
        _startTime = DateTime.now();
        _paymentStatusText = "";
      });
      _startTimer();
      _listenToSessionChanges(ref.id);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Błąd startu: $e")));
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  // --- NASŁUCHIWANIE ZMIAN ---
  void _listenToSessionChanges(String sessionId) {
    _sessionSubscription?.cancel();
    _sessionSubscription = FirebaseFirestore.instance
        .collection('parking_sessions')
        .doc(sessionId)
        .snapshots()
        .listen((snapshot) {
      
      if (!snapshot.exists) {
        _resetLocalSession();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sesja zakończona.")));
        return;
      }

      final data = snapshot.data();
      final status = data?['status'];

      if (status != 'active') {
        _resetLocalSession();
        _showPaidPopup(message: status == 'cash_settled' 
            ? "Zatrzymano przez właściciela (Gotówka)." 
            : "ZAPŁACONE - Możesz wyjechać.");
      }
    });
  }

  void _resetLocalSession() {
    _timer?.cancel();
    _sessionSubscription?.cancel();
    if (mounted) {
      setState(() {
        _activeSessionId = null;
        _activeParking = null;
        _startTime = null;
        _currentCost = 0.0;
        _elapsedTimeStr = "00:00:00";
        _paymentStatusText = "";
      });
    }
  }

  // 5. Timer (LOGIKA PRZELICZANIA)
  void _startTimer() {
    _timer?.cancel();
    // Odświeżaj co sekundę
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimerLogic();
    });
  }

  void _updateTimerLogic() {
    if (_startTime == null || _activeParking == null) return;

    final now = DateTime.now();
    final diff = now.difference(_startTime!);

    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');

    // --- ZMIANA: Nalicza dopiero PO 5 minutach ---
    double cost = 0.0;
    int totalMinutes = diff.inMinutes;
    int payableMinutes = totalMinutes - 5; // Odejmujemy 5 minut grace period

    if (payableMinutes > 0) {
      // Płacimy tylko za czas powyżej 5 minut
      double hours = payableMinutes / 60.0;
      cost = hours * _activeParking!.pricePerHour;
    } else {
      // W trakcie pierwszych 5 minut koszt to 0
      cost = 0.0;
    }

    setState(() {
      _elapsedTimeStr = "$h:$m:$s";
      _currentCost = cost;
    });
  }

  // 6. Stop i Płatność
  Future<void> _stopAndPay() async {
    setState(() => _isLoadingAction = true);

    try {
      // (Walidacja kosztu bez zmian...)
      if (_currentCost == 0.0) { /* ... */ return; }
      if (_currentCost < 2.00) { throw "Za mała kwota..."; }

      final ownerDoc = await FirebaseFirestore.instance.collection('owners').doc(_activeParking!.ownerUid).get();
      final ownerStripeId = ownerDoc.data()?['stripeAccountId'];
      if (ownerStripeId == null) throw "Właściciel nie skonfigurował płatności";

      // 1. Przygotowanie danych
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createPaymentIntent');
      final int amountInGrosze = (_currentCost * 100).toInt();
      
      // Pobieramy e-mail zalogowanego użytkownika
      final String userEmail = currentUser?.email ?? "unknown@example.com";

      // 2. Wywołanie Backend (wysyłamy email!)
      final result = await callable.call({
        'amount': amountInGrosze,
        'currency': 'pln',
        'ownerStripeId': ownerStripeId,
        'email': userEmail, // <--- WAŻNE: Wysyłamy email, żeby znaleźć klienta
      });

      final data = result.data; // Odbieramy obiekt z 3 kluczami

      // 3. Inicjalizacja Stripe z danymi Klienta
      await Stripe.instance.initPaymentSheet(paymentSheetParameters: SetupPaymentSheetParameters(
        // Klucze płatności
        paymentIntentClientSecret: data['paymentIntent'],
        
        // Klucze Klienta (To uruchamia zapisane karty!)
        customerEphemeralKeySecret: data['ephemeralKey'],
        customerId: data['customer'],
        
        merchantDisplayName: 'ParkCheck',
        style: ThemeMode.light,
        // paymentMethodOrder: ['card'], // Możesz to usunąć, jeśli chcesz pozwolić na Apple/Google Pay
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(primary: Colors.blue),
        ),
      ));

      // 4. Wyświetlenie arkusza
      await Stripe.instance.presentPaymentSheet();
      
      // 5. Sukces - Zapis do bazy
      await FirebaseFirestore.instance.collection('parking_sessions').doc(_activeSessionId).update({
        'endTime': FieldValue.serverTimestamp(),
        'status': 'completed',
        'cost': _currentCost,
      });

    } on StripeException catch (e) {
      setState(() {
        _paymentStatusText = "PŁATNOŚĆ ANULOWANA";
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Błąd: $e")));
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  void _showPaidPopup({String? message}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(minutes: 20), () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
        return AlertDialog(
          backgroundColor: Colors.green[50],
          icon: const Icon(Icons.check_circle, size: 60, color: Colors.green),
          title: const Text("GOTOWE"),
          content: Text(message ?? "ZAPŁACONE - Możesz wyjechać.", textAlign: TextAlign.center),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
          ],
        );
      },
    );
  }

  // --- UI GŁÓWNE ---

  @override
  Widget build(BuildContext context) {
    bool isParking = _activeSessionId != null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('PARK CHECK', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          // --- GUZIK DEBUGOWANIA (PRZEWIJANIE CZASU) ---
          if (isParking)
            IconButton(
              icon: const Icon(Icons.fast_forward, color: Colors.blue),
              tooltip: "Debug: Dodaj 15 minut",
              onPressed: _debugAdd15Minutes,
            ),
        ],
      ),
      body: StreamBuilder<List<ParkingAreaModel>>(
        stream: _parkingService.getParkingAreas(),
        builder: (context, snapshotAll) {
          return StreamBuilder<List<String>>(
            stream: _parkingService.getUserFavorites(),
            builder: (context, snapshotFav) {
              
              final allSpots = snapshotAll.data ?? [];
              final favIds = snapshotFav.data ?? [];

              ParkingAreaModel? nearestSpot;
              double distanceToNearest = double.infinity;

              if (_currentPosition != null && allSpots.isNotEmpty) {
                var sortedList = List<ParkingAreaModel>.from(allSpots);
                sortedList.sort((a, b) {
                  double distA = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, a.location.latitude, a.location.longitude);
                  double distB = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, b.location.latitude, b.location.longitude);
                  return distA.compareTo(distB);
                });
                nearestSpot = sortedList.first;
                distanceToNearest = Geolocator.distanceBetween(
                  _currentPosition!.latitude, _currentPosition!.longitude, 
                  nearestSpot.location.latitude, nearestSpot.location.longitude
                );
              }
              bool isNear = distanceToNearest <= 50;

              return Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildLicensePlateCard(),
                          
                          if (isParking) ...[
                            _buildActiveTimeCard(),
                          ] else ...[
                            const SizedBox(height: 20),
                            _buildFavoritesSection(allSpots, favIds),
                            const SizedBox(height: 20),
                            _buildNearestSection(allSpots, favIds),
                          ],
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: _buildMainActionButton(isParking, isNear, nearestSpot),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // --- WIDGETY SKŁADOWE ---

  Widget _buildLicensePlateCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0,5))],
      ),
      child: Column(
        children: [
          const Text('TWÓJ POJAZD', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 5),
          Text(
            _myLicensePlate,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTimeCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green, width: 2),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Text("PARKING: ${_activeParking?.name ?? '...'}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          Text(_elapsedTimeStr, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          const SizedBox(height: 10),
          Text("Koszt: ${_currentCost.toStringAsFixed(2)} zł", style: const TextStyle(fontSize: 20, color: Colors.blue, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text("(Pierwsze 5 min gratis)", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFavoritesSection(List<ParkingAreaModel> allSpots, List<String> favIds) {
    final favSpots = allSpots.where((s) => favIds.contains(s.id)).toList();
    if (favSpots.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.favorite, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text("ULUBIONE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))
          ]),
          const SizedBox(height: 10),
          ...favSpots.map((spot) => _buildParkingCard(spot, true)).toList(),
        ],
      ),
    );
  }

  Widget _buildNearestSection(List<ParkingAreaModel> allSpots, List<String> favIds) {
    if (_currentPosition == null) {
      return const Center(child: Text("Szukanie lokalizacji..."));
    }

    var sorted = List<ParkingAreaModel>.from(allSpots);
    sorted.sort((a, b) {
      double dA = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, a.location.latitude, a.location.longitude);
      double dB = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, b.location.latitude, b.location.longitude);
      return dA.compareTo(dB);
    });
    final top3 = sorted.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("W POBLIŻU", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          ...top3.map((spot) => _buildParkingCard(spot, favIds.contains(spot.id))).toList(),
        ],
      ),
    );
  }

  Widget _buildParkingCard(ParkingAreaModel spot, bool isFav) {
    double? km;
    if (_currentPosition != null) {
      km = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, spot.location.latitude, spot.location.longitude) / 1000;
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.local_parking, color: Colors.blue),
        ),
        title: Text(spot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(km != null ? "${km.toStringAsFixed(2)} km • ${spot.pricePerHour} zł/h" : "${spot.pricePerHour} zł/h"),
        trailing: IconButton(
          icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey),
          onPressed: () => _parkingService.toggleFavorite(spot.id),
        ),
      ),
    );
  }

  Widget _buildMainActionButton(bool isParking, bool isNear, ParkingAreaModel? nearestSpot) {
    String text;
    Color bgColor;
    VoidCallback? action;
    bool isDisabled = false;

    if (_isLoadingAction) {
      return Container(
        height: 70,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)]),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (isParking) {
      if (_paymentStatusText.isNotEmpty) {
        text = _paymentStatusText;
        bgColor = Colors.red;
        action = _stopAndPay;
      } else {
        // --- LOGIKA BLOKADY ---
        if (_currentCost == 0.0) {
          // Darmowe 5 min -> Można wyjść
          text = "ZAKOŃCZ BEZPŁATNIE";
          bgColor = Colors.green;
          action = _stopAndPay;
        } else if (_currentCost > 0.0 && _currentCost < 2.00) {
          // Koszt między 0.01 a 1.99 -> BLOKADA
          text = "MINIMUM 2 ZŁ (${_currentCost.toStringAsFixed(2)})";
          bgColor = Colors.grey;
          isDisabled = true;
          action = null;
        } else {
          // Powyżej 2 zł -> PŁAĆ
          text = "ZATRZYMAJ I ZAPŁAĆ";
          bgColor = Colors.red;
          action = _stopAndPay;
        }
      }
    } else {
      if (isNear && nearestSpot != null) {
        text = "ROZPOCZNIJ PARKOWANIE\n(${nearestSpot.name})";
        bgColor = Colors.green;
        action = () => _startParkingSession(nearestSpot!);
      } else {
        text = "NIE JESTEŚ W POBLIŻU\n(Podjedź na 50m)";
        bgColor = Colors.orange;
        isDisabled = true;
        action = null; 
      }
    }

    return SizedBox(
      width: double.infinity,
      height: 75,
      child: ElevatedButton(
        onPressed: action,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: isDisabled ? 0 : 5,
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}