import 'package:flutter/material.dart';

class OccupancyBar extends StatelessWidget {
  final int occupied;
  final int capacity;

  const OccupancyBar({
    super.key,
    required this.occupied,
    required this.capacity,
  });

  @override
  Widget build(BuildContext context) {
    // Obliczamy procent zajętości (od 0.0 do 1.0)
    final double percent = (capacity > 0) ? (occupied / capacity) : 0.0;
    
    // Logika kolorów:
    // < 50% -> Niebieski
    // 50% - 85% -> Żółty (Amber)
    // > 85% -> Czerwony
    Color barColor;
    if (percent < 0.5) {
      barColor = Colors.blue;
    } else if (percent < 0.85) {
      barColor = Colors.amber;
    } else {
      barColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Pasek
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 4),
        // Tekst np. "5 / 16"
        Text(
          "$occupied / $capacity",
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}