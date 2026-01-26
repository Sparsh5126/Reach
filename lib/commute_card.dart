import 'package:flutter/material.dart';

class CommuteCard extends StatelessWidget {
  final String title;
  final String arriveBy;
  final String leaveBy;
  final String readyBy;
  final String mode;
  final List<String> days;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const CommuteCard({
    super.key,
    required this.title,
    required this.arriveBy,
    required this.leaveBy,
    required this.readyBy,
    required this.mode,
    required this.days,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildIcon(),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text("Arrive $arriveBy • ${days.join('')}", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("LEAVE BY", style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.w900)),
                    Text(leaveBy, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ],
            ),
            const Divider(height: 25, color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text("Get Ready (Pack):", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
                Text(readyBy, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    switch (mode) {
      case 'motorcycle': iconData = Icons.motorcycle; break;
      case 'train': iconData = Icons.train; break;
      case 'flight': iconData = Icons.flight; break;
      default: iconData = Icons.directions_car;
    }
    return Icon(iconData, color: Colors.orange[800], size: 20);
  }
}