import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles.dart';

class PrivacyDialog extends StatelessWidget {
  const PrivacyDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent dismissing with back button
        child: const PrivacyDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? ReachStyles.darkText : ReachStyles.lightText;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final accentColor = ReachStyles.primaryOrange;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon and Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.security_rounded,
                      color: accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Privacy & Data",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Introduction
              Text(
                "To calculate smart travel times and schedule alarms, Reach utilizes the following data:",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Bullet points of permissions/data
              _buildConsentItem(
                icon: Icons.location_on_rounded,
                color: Colors.blueAccent,
                title: "Location Access",
                description:
                    "Used to fetch real-time traffic and route travel durations dynamically.",
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildConsentItem(
                icon: Icons.calendar_month_rounded,
                color: Colors.greenAccent[700]!,
                title: "Calendar Scanning",
                description:
                    "Scans travel events locally on-device to auto-setup leave reminders.",
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildConsentItem(
                icon: Icons.notifications_active_rounded,
                color: Colors.orangeAccent[700]!,
                title: "Smart Notifications",
                description:
                    "Triggers leave-now alarms and pack-up notifications in the background.",
                isDark: isDark,
              ),

              const SizedBox(height: 24),
              Divider(color: isDark ? Colors.white10 : Colors.grey[200]),
              const SizedBox(height: 12),

              // Local processing assurance
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "All calculations are performed locally. Your personal data is never shared with third parties or ad networks.",
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Accept Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    "Agree & Continue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
