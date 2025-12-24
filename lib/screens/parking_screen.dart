import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
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

  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isLoadingAction = false;
  
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

  // --- DEBUGOWANIE ---
  void _debugAdd15Minutes() {
    if (_startTime != null) {
      setState(() {
        _startTime = _startTime!.subtract(const Duration(minutes: 15));
      });
      _updateTimerLogic();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("DEBUG: Dodano 15 minut"), 
        duration: Duration(seconds: 1)
      ));
    }
  }

  // --- LOGIKA BIZNESOWA ---

  void _fetchUserData() async {
    if (currentUser == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    if (mounted && doc.exists) {
      setState(() {
        _myLicensePlate = doc.data()?['licensePlate'] ?? "BRAK";
      });
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingLocation = false);
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

      Geolocator.getPositionStream().listen((Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _isLoadingLocation = false;
          });
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    } else {
      return "${meters.toInt()} m";
    }
  }

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

  void _startParkingSession(ParkingAreaModel parking) async {
    if (_myLicensePlate == "BRAK" || _myLicensePlate == "Ładowanie...") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uzupełnij tablicę w profilu!")));
      return;
    }

    setState(() => _isLoadingAction = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. <<< NOWOŚĆ: Sprawdź RZECZYWISTĄ liczbę aktywnych sesji przed startem >>>
      // Ignorujemy pole 'occupiedSpots' w dokumencie parkingu, bo może być błędne (np. 8/5)
      final activeSessionsSnapshot = await firestore
          .collection('parking_sessions')
          .where('parkingId', isEqualTo: parking.id)
          .where('status', isEqualTo: 'active')
          .get();

      final int realOccupiedCount = activeSessionsSnapshot.docs.length;

      if (realOccupiedCount >= parking.totalCapacity) {
        // Jeśli jest pełny, przerywamy i wyświetlamy błąd
        throw Exception("Parking jest pełny! (${realOccupiedCount}/${parking.totalCapacity})");
      }
      // -----------------------------------------------------------------------

      final parkingRef = firestore.collection('parking_spots').doc(parking.id);
      final sessionRef = firestore.collection('parking_sessions').doc();

      await firestore.runTransaction((transaction) async {
        final parkingSnapshot = await transaction.get(parkingRef);
        
        if (!parkingSnapshot.exists) {
          throw Exception("Parking nie istnieje!");
        }

        // Aktualizujemy licznik w bazie (nawet jak jest zły, dodajemy +1, ale ważniejsze jest sprawdzenie wyżej)
        int currentOccupiedInDb = parkingSnapshot.data()?['occupiedSpots'] ?? 0;
        
        transaction.update(parkingRef, {
          'occupiedSpots': currentOccupiedInDb + 1
        });

        transaction.set(sessionRef, {
          'parkingId': parking.id,
          'parkingName': parking.name,
          'ownerId': parking.ownerUid,
          'driverId': currentUser!.uid,
          'licensePlate': _myLicensePlate,
          'startTime': FieldValue.serverTimestamp(),
          'status': 'active',
          'cost': 0.0,
        });
      });

      setState(() {
        _activeSessionId = sessionRef.id;
        _activeParking = parking;
        _startTime = DateTime.now();
        _paymentStatusText = "";
      });
      _startTimer();
      _listenToSessionChanges(sessionRef.id);

    } catch (e) {
      // Wyświetlanie błędu (np. o pełnym parkingu)
      String errorMsg = e.toString();
      if (errorMsg.contains("Exception:")) {
        errorMsg = errorMsg.replaceAll("Exception: ", "");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        )
      );
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  void _listenToSessionChanges(String sessionId) {
    _sessionSubscription?.cancel();
    _sessionSubscription = FirebaseFirestore.instance
        .collection('parking_sessions')
        .doc(sessionId)
        .snapshots()
        .listen((snapshot) {
      
      if (!snapshot.exists) {
        _resetLocalSession();
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

  void _startTimer() {
    _timer?.cancel();
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

    double cost = 0.0;
    int totalMinutes = diff.inMinutes;
    int payableMinutes = totalMinutes - 5; 

    if (payableMinutes > 0) {
      double hours = payableMinutes / 60.0;
      cost = hours * _activeParking!.pricePerHour;
    } else {
      cost = 0.0;
    }

    setState(() {
      _elapsedTimeStr = "$h:$m:$s";
      _currentCost = cost;
    });
  }

  Future<void> _stopAndPay() async {
    setState(() => _isLoadingAction = true);

    try {
      if (_currentCost == 0.0) {
         await _finalizeSessionInDb(paid: true, isFree: true);
         return; 
      }

      if (_currentCost < 2.00) { 
        throw "Kwota poniżej 2 zł nie jest obsługiwana przez płatności online."; 
      }

      final ownerDoc = await FirebaseFirestore.instance.collection('owners').doc(_activeParking!.ownerUid).get();
      final ownerStripeId = ownerDoc.data()?['stripeAccountId'];
      if (ownerStripeId == null) throw "Właściciel nie skonfigurował płatności";

      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createPaymentIntent');
      final int amountInGrosze = (_currentCost * 100).toInt();
      final String userEmail = currentUser?.email ?? "unknown@example.com";

      final result = await callable.call({
        'amount': amountInGrosze,
        'currency': 'pln',
        'ownerStripeId': ownerStripeId,
        'email': userEmail,
      });

      final data = result.data;

      await Stripe.instance.initPaymentSheet(paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: data['paymentIntent'],
        customerEphemeralKeySecret: data['ephemeralKey'],
        customerId: data['customer'],
        merchantDisplayName: 'ParkCheck',
        style: ThemeMode.light,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(primary: Colors.blue),
        ),
      ));

      await Stripe.instance.presentPaymentSheet();
      
      // SUKCES: Jeśli kod doszedł tutaj, czyścimy ewentualne błędy w bazie
      await FirebaseFirestore.instance.collection('parking_sessions').doc(_activeSessionId).update({
        'paymentStatus': 'success', // NOWE
        'lastError': FieldValue.delete(), // NOWE
      });

      await _finalizeSessionInDb(paid: true, isFree: false);

    } on StripeException catch (e) {
      // PORAŻKA STRIPE: Zapisujemy to w bazie, żeby Właściciel widział!
      // --- NOWA SEKCJA START ---
      if (_activeSessionId != null) {
        FirebaseFirestore.instance.collection('parking_sessions').doc(_activeSessionId).update({
          'paymentStatus': 'failed',
          'lastError': 'Płatność odrzucona: ${e.error.localizedMessage}',
          'lastAttemptTime': FieldValue.serverTimestamp(),
        });
      }
      // --- NOWA SEKCJA STOP ---

      if (e.error.code == FailureCode.Canceled) {
        setState(() {
          _paymentStatusText = "PŁATNOŚĆ ANULOWANA";
        });
      } else {
        setState(() {
          _paymentStatusText = "BŁĄD PŁATNOŚCI";
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Błąd Stripe: ${e.error.localizedMessage}")));
      }
    } catch (e) {
       // INNE BŁĘDY: Też możemy zapisać
      if (_activeSessionId != null) {
        FirebaseFirestore.instance.collection('parking_sessions').doc(_activeSessionId).update({
          'paymentStatus': 'error',
          'lastError': e.toString(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Błąd: $e")));
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _finalizeSessionInDb({required bool paid, required bool isFree}) async {
    final firestore = FirebaseFirestore.instance;
    final parkingRef = firestore.collection('parking_spots').doc(_activeParking!.id);
    final sessionRef = firestore.collection('parking_sessions').doc(_activeSessionId);

    await firestore.runTransaction((transaction) async {
       final parkingSnapshot = await transaction.get(parkingRef);

       if (parkingSnapshot.exists) {
         int currentOccupied = parkingSnapshot.data()?['occupiedSpots'] ?? 0;
         int newOccupancy = currentOccupied > 0 ? currentOccupied - 1 : 0;
         transaction.update(parkingRef, {
           'occupiedSpots': newOccupancy
         });
       }

       transaction.update(sessionRef, {
        'endTime': FieldValue.serverTimestamp(),
        'status': 'completed',
        'cost': _currentCost,
        'paid': paid,
        'isFreeExit': isFree
      });
    });
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Zaokrąglenie samego okienka
          ),
          icon: const Icon(Icons.check_circle, size: 60, color: Colors.blue),
          title: const Text("GOTOWE"),
          content: Text(
            message ?? "ZAPŁACONE - Możesz wyjechać.",
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10), // Odstęp od dołu okna
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Tło niebieskie
                  foregroundColor: Colors.white, // Tekst biały
                  // Poniżej kluczowe zmiany dla wyglądu "głównego przycisku":
                  minimumSize: const Size(200, 50), // Szerokość: 200, Wysokość: 50
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Zaokrąglenie rogów przycisku
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18, // Większa czcionka
                    fontWeight: FontWeight.bold, // Pogrubienie tekstu
                  ),
                  elevation: 5, // Lekki cień pod przyciskiem
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            )
          ],
        );
      },
    );
}

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    bool isParking = _activeSessionId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      resizeToAvoidBottomInset: false, 
      body: SafeArea(
        bottom: false, 
        child: Stack(
          children: [
            // TREŚĆ (Listy)
            StreamBuilder<List<ParkingAreaModel>>(
              stream: _parkingService.getParkingAreas(), 
              builder: (context, snapshotAll) {
                if (snapshotAll.hasError) return const Center(child: Text("Błąd danych parkingów"));
                
                final allSpots = snapshotAll.data ?? [];

                // Decyzja czy pokazać panel info (potrzebna do paddingu)
                ParkingAreaModel? nearestForCheck;
                bool isNearForCheck = false;
                if (_currentPosition != null && allSpots.isNotEmpty) {
                   double minDst = double.infinity;
                   for(var s in allSpots) {
                     double d = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, s.location.latitude, s.location.longitude);
                     if(d < minDst) {
                       minDst = d;
                       nearestForCheck = s;
                     }
                   }
                   if (minDst <= 50) isNearForCheck = true;
                }
                
                // Logika paddingu listy
                bool showInfoPanel = !isParking && isNearForCheck && nearestForCheck != null;
                final double contentPaddingBottom = showInfoPanel ? 250.0 : 100.0;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('parking_sessions')
                      .where('status', isEqualTo: 'active')
                      .snapshots(),
                  builder: (context, snapshotSessions) {
                    
                    Map<String, int> activeCounts = {};
                    if (snapshotSessions.hasData) {
                      for (var doc in snapshotSessions.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final pId = data['parkingId'] as String?;
                        if (pId != null) {
                          activeCounts[pId] = (activeCounts[pId] ?? 0) + 1;
                        }
                      }
                    }

                    return StreamBuilder<List<String>>(
                      stream: _parkingService.getUserFavorites(),
                      builder: (context, snapshotFav) {
                        
                        final favIds = snapshotFav.data ?? [];
                        List<ParkingAreaModel> sortedSpots = List.from(allSpots);

                        if (_currentPosition != null && sortedSpots.isNotEmpty) {
                          sortedSpots.sort((a, b) {
                            double distA = Geolocator.distanceBetween(
                              _currentPosition!.latitude, _currentPosition!.longitude, 
                              a.location.latitude, a.location.longitude
                            );
                            double distB = Geolocator.distanceBetween(
                              _currentPosition!.latitude, _currentPosition!.longitude, 
                              b.location.latitude, b.location.longitude
                            );
                            return distA.compareTo(distB);
                          });
                        }

                        final favSpots = sortedSpots.where((s) => favIds.contains(s.id)).toList();

                        return SingleChildScrollView(
                          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: contentPaddingBottom),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 20),
                              
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: isParking 
                                  ? _buildActiveSessionCard(isParking)
                                  : _buildUserCarCard(),
                              ),

                              const SizedBox(height: 30),
                              
                              if (favSpots.isNotEmpty) ...[
                                _buildSectionTitle("Ulubione parkingi", Icons.favorite, Colors.red),
                                const SizedBox(height: 12),
                                _buildHorizontalList(
                                  favSpots, 
                                  favIds, 
                                  isFavoriteList: true,
                                  activeCounts: activeCounts, 
                                ),
                                const SizedBox(height: 24),
                              ],
                              
                              _buildSectionTitle("Parkingi w pobliżu", Icons.wifi_tethering, Colors.black),
                              const SizedBox(height: 12),
                              _buildHorizontalList(
                                sortedSpots, 
                                favIds, 
                                isFavoriteList: false,
                                activeCounts: activeCounts, 
                              ), 
                            ],
                          ),
                        );
                      }
                    );
                  }
                );
              }
            ),

            // PŁYWAJĄCE ELEMENTY (STICKY)
            StreamBuilder<List<ParkingAreaModel>>(
              stream: _parkingService.getParkingAreas(),
              builder: (ctx, snap) {
                List<ParkingAreaModel> spots = snap.data ?? [];
                ParkingAreaModel? nearestForButton;
                bool isNear = false;

                if (_currentPosition != null && spots.isNotEmpty) {
                  spots.sort((a, b) {
                     double distA = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, a.location.latitude, a.location.longitude);
                     double distB = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, b.location.latitude, b.location.longitude);
                     return distA.compareTo(distB);
                  });
                  nearestForButton = spots.first;
                  double dist = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, nearestForButton.location.latitude, nearestForButton.location.longitude);
                  isNear = dist <= 50; 
                }

                bool showInfoPanel = !isParking && isNear && nearestForButton != null;

                return Stack(
                  children: [
                    // A. PANEL INFO
                    if (showInfoPanel)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 96, 
                        child: _buildNearestSpotInfo(nearestForButton!),
                      ),

                    // B. GUZIK
                    Positioned(
                      bottom: 16, 
                      left: 16,
                      right: 16,
                      child: _buildMainActionButton(isParking, isNear, nearestForButton),
                    ),
                  ],
                );
              }
            )
          ],
        ),
      ),
    );
  }

  // --- WIDGETY POMOCNICZE ---

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFF007AFF), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("PARK", style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w900, fontSize: 18, height: 1)),
                Text("CHECK", style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w900, fontSize: 18, height: 1)),
              ],
            )
          ],
        ),
        if (_activeSessionId != null)
          IconButton(
            icon: const Icon(Icons.fast_forward, color: Colors.grey),
            tooltip: "Debug: Dodaj 15 min",
            onPressed: _debugAdd15Minutes,
          ),
      ],
    );
  }

  Widget _buildNearestSpotInfo(ParkingAreaModel spot) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))
        ],
        border: Border.all(color: const Color(0xFF007AFF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pin_drop, color: Color(0xFF007AFF), size: 20),
              const SizedBox(width: 8),
              const Text("TU ZAPARKUJESZ:", style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            spot.name, 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            maxLines: 1, 
            overflow: TextOverflow.ellipsis
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  spot.address,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserCarCard() {
    return Container(
      key: const ValueKey('CarCard'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF007AFF), width: 2)),
            child: const Icon(Icons.directions_car, color: Color(0xFF007AFF), size: 30),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("TWOJE AUTO", style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Text("nr rej. ", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    Text(_myLicensePlate.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard(bool isParking) {
    return Container(
      key: const ValueKey('TimerCard'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.3)),
        boxShadow: [BoxShadow(color: const Color(0xFF007AFF).withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: IntrinsicHeight( 
        child: Row(
          children: [
            Expanded(
              flex: 5, 
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.watch_later_outlined, color: Color(0xFF007AFF), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          _elapsedTimeStr,
                          style: const TextStyle(
                            fontSize: 22, 
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF007AFF), 
                            fontFeatures: [FontFeature.tabularFigures()]
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text("DO ZAPŁATY", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(
                      "${_currentCost.toStringAsFixed(2)} zł",
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            VerticalDivider(color: Colors.grey.shade200, thickness: 1, width: 1),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("PARKUJESZ NA:", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      _activeParking?.name ?? "...",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activeParking?.address ?? "...",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
      ],
    );
  }

  Widget _buildHorizontalList(
    List<ParkingAreaModel> spots, 
    List<String> favIds, 
    {required bool isFavoriteList, required Map<String, int> activeCounts}) {
      
    if (spots.isEmpty) {
      return SizedBox(
        height: 50,
        child: Center(child: Text(isFavoriteList ? "" : "Brak parkingów w pobliżu")),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        key: ValueKey('list_${isFavoriteList ? "fav" : "near"}_${spots.length}'), 
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: spots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 15),
        itemBuilder: (context, index) {
          final spot = spots[index];
          final isFav = favIds.contains(spot.id);
          final int realOccupancy = activeCounts[spot.id] ?? 0;

          String distanceText = "";
          if (_currentPosition != null) {
            double dist = Geolocator.distanceBetween(
              _currentPosition!.latitude, _currentPosition!.longitude, 
              spot.location.latitude, spot.location.longitude
            );
            distanceText = _formatDistance(dist);
          }

          // --- LOGIKA KOLORÓW DLA ZAJĘTOŚCI ---
          Color occupancyColor;
          double ratio = spot.totalCapacity > 0 ? realOccupancy / spot.totalCapacity : 0.0;

          if (ratio >= 0.9) {
            occupancyColor = Colors.red;
          } else if (ratio >= 0.5) {
            occupancyColor = Colors.amber[800]!; // Żółty/Pomarańczowy (czytelniejszy na białym)
          } else {
            occupancyColor = const Color(0xFF007AFF); // Niebieski (Domyślny)
          }

          return Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD0E6FF),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFF007AFF)),
                      const SizedBox(height: 5),
                      Text("${spot.pricePerHour}zł/h", style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(spot.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            GestureDetector(
                              onTap: () => _parkingService.toggleFavorite(spot.id),
                              child: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 18, color: isFav ? Colors.red : Colors.grey),
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(spot.address, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (distanceText.isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.near_me, size: 12, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(distanceText, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              )
                            else 
                              const SizedBox(), 

                            Text(
                              "$realOccupancy / ${spot.totalCapacity}", 
                              style: TextStyle(color: occupancyColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainActionButton(bool isParking, bool isNear, ParkingAreaModel? nearestSpot) {
    String text;
    Color bgColor;
    VoidCallback? action;
    bool isDisabled = false;

    if (_isLoadingAction) {
       return SizedBox(
        height: 70,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: () {}, 
          child: const CircularProgressIndicator()
        ),
      );
    }

    if (isParking) {
      if (_paymentStatusText.isNotEmpty) {
        text = _paymentStatusText;
        bgColor = Colors.red;
        action = _stopAndPay;
      } else if (_currentCost == 0.0) {
        text = "ZAKOŃCZ BEZPŁATNIE";
        bgColor = Colors.green;
        action = _stopAndPay; 
      } else {
        text = "ZAKOŃCZ I ZAPŁAĆ";
        bgColor = Colors.redAccent;
        action = _stopAndPay;
      }
    } else {
      if (isNear && nearestSpot != null) {
        text = "ROZPOCZNIJ PARKOWANIE"; 
        bgColor = const Color(0xFF007AFF);
        action = () => _startParkingSession(nearestSpot);
      } else {
        text = "PODJEDŹ BLIŻEJ PARKINGU";
        bgColor = Colors.grey;
        isDisabled = true;
        action = null;
      }
    }

    return SizedBox(
      width: double.infinity,
      height: 70,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: isDisabled ? 0 : 8,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: action,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isParking ? Icons.payment : Icons.local_parking, size: 28),
            const SizedBox(width: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}