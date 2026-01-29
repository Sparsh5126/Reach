import 'package:flutter/material.dart';

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
    
    // Background: Dark Grey (Dark Mode) vs White (Light Mode)
    final bgColor = isDark 
        ? const Color(0xFF1E1E1E).withOpacity(0.95) 
        : Colors.white.withOpacity(0.95);
        
    // Border: Subtle white (Dark) vs Subtle grey (Light)
    final borderColor = isDark 
        ? Colors.white.withOpacity(0.05) 
        : Colors.black.withOpacity(0.05);

    // Text: Grey (Dark) vs Dark Grey (Light) when unselected
    final unselectedTextColor = isDark ? Colors.grey[500] : Colors.grey[600];
    
    // Shadow: Add a subtle shadow in Light Mode to lift it off the white background
    final List<BoxShadow> shadows = [
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
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double innerWidth = constraints.maxWidth;
          double innerHeight = constraints.maxHeight;
          double pillWidth = innerWidth / 2;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutBack,
                top: 0,
                bottom: 0,
                left: selectedIndex == 0 ? 0 : pillWidth,
                width: pillWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange[800], // Orange pill looks good on both
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
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
      onTap: () => onTabChange(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              // Selected is always White (because pill is Orange)
              // Unselected adapts to the theme
              color: isSelected ? Colors.white : unselectedColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              fontFamily: 'Roboto', // Ensure font consistency
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}