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
    double totalWidth = MediaQuery.of(context).size.width * 0.75;
    double totalHeight = 60;

    return Container(
      width: totalWidth,
      height: totalHeight,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
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
                    color: Colors.orange[800],
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildTabItem("Commutes", 0, pillWidth, innerHeight),
                  _buildTabItem("Add New", 1, pillWidth, innerHeight),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabItem(String label, int index, double width, double height) {
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
              color: isSelected ? Colors.white : Colors.grey[500],
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}