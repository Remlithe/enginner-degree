// lib/widgets/license_plate_input.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LicensePlateInput extends StatelessWidget {
  final TextEditingController controller;

  const LicensePlateInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Kolor niebieski z polskich tablic
    final euroBlue = const Color(0xFF003399); 

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: euroBlue, width: 3),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // --- LEWA STRONA: NIEBIESKI PASEK "PL" ---
          Container(
            width: 50,
            decoration: BoxDecoration(
              color: euroBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                bottomLeft: Radius.circular(5),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.stars, color: Colors.amber, size: 16),
                SizedBox(height: 2),
                Text(
                  "PL",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          // --- PRAWA STRONA: POLE TEKSTOWE ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.black87,
                  fontFamily: 'RobotoMono', 
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'PO 12345',
                  hintStyle: TextStyle(color: Colors.black26),
                  counterText: "",
                  contentPadding: EdgeInsets.zero,
                ),
                // Zwiększamy limit do 10 (np. "GDA 12345" ma 9, plus zapas)
                maxLength: 10, 
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.visiblePassword, 
                inputFormatters: [
                  // Pozwalamy na litery, cyfry i spację
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')), 
                  // Nasz inteligentny formater
                  _SmartPlateFormatter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- INTELIGENTNY FORMATER ---
// Obsługuje 1, 2 lub 3 litery na początku + Cyfry
class _SmartPlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text.toUpperCase();
    
    // 1. Jeśli użytkownik kasuje znak (backspace), pozwalamy mu na wszystko
    if (newText.length < oldValue.text.length) {
      return newValue.copyWith(text: newText);
    }

    // 2. Czyścimy spacje, żeby przeanalizować "surowy" ciąg (np. "PO123")
    String cleanText = newText.replaceAll(' ', '');
    
    // Jeśli pusty, zwracamy
    if (cleanText.isEmpty) return newValue;

    // 3. Logika wykrywania, gdzie wstawić spację
    int splitIndex = 3; // Domyślnie po 3 literach (np. GDA ...)

    // Szukamy pierwszej cyfry w ciągu
    int firstDigitIndex = cleanText.indexOf(RegExp(r'[0-9]'));

    if (firstDigitIndex != -1) {
      // Jeśli znaleźliśmy cyfrę (np. w "PO123" indeks cyfry '1' to 2)
      // To oznacza, że prefiks to litery PRZED tą cyfrą.
      // Ale prefiks musi mieć max 3 znaki.
      if (firstDigitIndex <= 3) {
        splitIndex = firstDigitIndex;
      }
    } else {
      // Jeśli nie ma cyfr, sprawdzamy czy użytkownik wpisał spację ręcznie
      // np. wpisał "PO "
      if (newValue.text.endsWith(' ')) {
         // Jeśli spacja jest po 1, 2 lub 3 znaku, uznajemy to za podział
         int spacePos = newValue.text.indexOf(' ');
         if (spacePos > 0 && spacePos <= 3) {
           splitIndex = spacePos;
         }
      }
    }

    // 4. Budowanie sformatowanego tekstu
    String formatted = "";
    if (cleanText.length > splitIndex) {
      // Wstawiamy spację w wyliczonym miejscu
      formatted = "${cleanText.substring(0, splitIndex)} ${cleanText.substring(splitIndex)}";
    } else {
      // Jeśli tekst jest krótszy niż punkt podziału (np. wpisujemy "PO"), 
      // ale użytkownik nacisnął spację, dodajemy ją na końcu
      if (newValue.text.endsWith(' ') && cleanText.length <= 3) {
         formatted = "$cleanText ";
      } else {
         formatted = cleanText;
      }
    }

    // Ograniczenie długości (np. max 8 znaków po spacji)
    // Bezpiecznik: przycinamy, jeśli za długie
    if (formatted.length > 10) {
      formatted = formatted.substring(0, 10);
    }

    return TextEditingValue(
      text: formatted,
      // Ustawiamy kursor zawsze na końcu
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}