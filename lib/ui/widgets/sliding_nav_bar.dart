import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SlidingNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChange;

  const SlidingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    // --- THEME COLORS ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Background: Use Dynamic Card Color
    final bgColor = isDark 
        ? Theme.of(context).cardColor.withOpacity(0.95) 
        : Colors.white.withOpacity(0.95);
        
    // Border: Subtle white (Dark) vs Subtle grey (Light)
    final borderColor = isDark 
        ? Colors.white.withOpacity(0.05) 
        : Colors.black.withOpacity(0.05);

    // Text Colors
    final unselectedTextColor = isDark ? Colors.grey[500] : Colors.grey[600];
    
    // Shadow: Lift the entire bar slightly
    final List<BoxShadow> barShadows = [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ];

    double totalWidth = MediaQuery.of(context).size.width * 0.75;
    double totalHeight = 60;

    return Container(
      width: totalWidth,
      height: totalHeight,
      padding: const EdgeInsets.all(5), // Padding creates the "floating" effect
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100), // Max radius for outer container
        border: Border.all(color: borderColor),
        boxShadow: barShadows,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double innerWidth = constraints.maxWidth;
          double innerHeight = constraints.maxHeight;
          double pillWidth = innerWidth / 2;

          return Stack(
            children: [
              // --- THE MOVING ORANGE PILL ---
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutBack,
                top: 0,
                bottom: 0,
                left: selectedIndex == 0 ? 0 : pillWidth,
                width: pillWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange[800],
                    borderRadius: BorderRadius.circular(100), 
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
              
              // --- TAB TEXT ITEMS ---
              Row(
                children: [
                  _buildTabItem("Commutes", 0, pillWidth, innerHeight, unselectedTextColor),
                  _buildTabItem("Add New", 1, pillWidth, innerHeight, unselectedTextColor),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabItem(String label, int index, double width, double height, Color? unselectedColor) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTabChange(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isSelected ? Colors.white : unselectedColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              fontFamily: 'Roboto',
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}