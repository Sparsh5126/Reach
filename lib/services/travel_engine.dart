import 'package:shared_preferences/shared_preferences.dart';
import '../models/commute_model.dart';
import 'commute_history_service.dart';

class TravelPrediction {
  final int mapplsDuration;
  final int weatherAdjustment;
  final int predictedTravel; // The final actual predicted travel time
  final int safetyBuffer;
  final int gettingReadyTime;
  final DateTime leaveBy;
  final DateTime readyAt;
  final DateTime arriveAt; // Exposed for check-in notification
  final String diagnostics;

  // Added fields to help the UI breakdown
  final HistoryEstimate? historyEstimate;
  final bool isFallback;

  TravelPrediction({
    required this.mapplsDuration,
    required this.weatherAdjustment,
    required this.predictedTravel,
    required this.safetyBuffer,
    required this.gettingReadyTime,
    required this.leaveBy,
    required this.readyAt,
    required this.arriveAt,
    required this.diagnostics,
    this.historyEstimate,
    this.isFallback = false,
  });
}

class TravelEngine {
  /// Computes the complete timing pipeline.
  static Future<TravelPrediction> compute({
    required Commute commute,
    required int mapplsDuration, // Fetched from Mappls Distance Matrix
    required double rainFactor,  // Fetched from WeatherService
    bool isFallback = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Weather Adjustment
    // Convert rainFactor to explicit minutes. 
    // e.g. factor 1.2 = 20% increase.
    int weatherAdjustment = 0;
    if (rainFactor > 1.0) {
      weatherAdjustment = (mapplsDuration * (rainFactor - 1.0)).round();
    }

    // 2. Learning History Adjustment
    // History predicts travel time (replacing Mappls, or blending with it)
    HistoryEstimate history = await CommuteHistoryService.getPredictedTravel(
      commuteId: commute.id,
      mode: commute.mode,
      mapplsMinutes: mapplsDuration,
    );

    int predictedTravel = history.predictedMinutes + weatherAdjustment;

    // 3. Safety Buffer (user preference)
    int safetyBuffer = commute.safetyBufferMinutes;

    // 4. Getting Ready Time
    int gettingReadyTime = prefs.getInt('getting_ready_time') ?? 15;

    // 5. Calculate Timestamps
    final now = DateTime.now();
    int targetHour = 9;
    int targetMinute = 0;

    try {
      final timeParts = commute.time.split(" ");
      final hm = timeParts[0].split(":");
      targetHour = int.parse(hm[0]);
      targetMinute = int.parse(hm[1]);
      if (timeParts[1] == "PM" && targetHour != 12) targetHour += 12;
      if (timeParts[1] == "AM" && targetHour == 12) targetHour = 0;
    } catch (_) {}

    // Use _nextInstanceOfDayAndTime logic (same as what was fixed before for timezone)
    // For calculating the exact day to attach the time to.
    DateTime arriveAt = DateTime(
      now.year,
      now.month,
      now.day,
      targetHour,
      targetMinute,
    );
    
    // If arrival time has passed, schedule for tomorrow.
    if (arriveAt.isBefore(now)) {
      arriveAt = arriveAt.add(const Duration(days: 1));
    }

    // Subtract to find Leave Time
    int totalTravelAllowance = predictedTravel + safetyBuffer;
    
    // Round down behavior: subtract exact minutes, set seconds/milliseconds to 0.
    DateTime leaveBy = arriveAt.subtract(Duration(minutes: totalTravelAllowance));
    leaveBy = DateTime(leaveBy.year, leaveBy.month, leaveBy.day, leaveBy.hour, leaveBy.minute);

    // Subtract getting ready time
    DateTime readyAt = leaveBy.subtract(Duration(minutes: gettingReadyTime));
    readyAt = DateTime(readyAt.year, readyAt.month, readyAt.day, readyAt.hour, readyAt.minute);

    // Ensure we don't schedule alarms in the past
    if (!readyAt.isAfter(now)) {
      arriveAt = arriveAt.add(const Duration(days: 1));
      leaveBy = arriveAt.subtract(Duration(minutes: totalTravelAllowance));
      leaveBy = DateTime(leaveBy.year, leaveBy.month, leaveBy.day, leaveBy.hour, leaveBy.minute);
      readyAt = leaveBy.subtract(Duration(minutes: gettingReadyTime));
      readyAt = DateTime(readyAt.year, readyAt.month, readyAt.day, readyAt.hour, readyAt.minute);
    }

    // Build Diagnostics string
    final diag = StringBuffer();
    diag.writeln("Mode: ${commute.mode}");
    diag.writeln("Origin: Current/Saved");
    diag.writeln("Destination: ${commute.customTitle ?? commute.title}");
    diag.writeln("");
    diag.writeln("Mappls duration: $mapplsDuration min");
    diag.writeln("Mappls traffic-aware: no (Distance Matrix)");
    diag.writeln("");
    diag.writeln("Learning History:");
    diag.writeln("Sample count: ${history.sampleCount}");
    diag.writeln("Historical estimate: ${history.predictedMinutes} min (${history.tier})");
    diag.writeln("");
    diag.writeln("Weather adjustment: +$weatherAdjustment min (factor: $rainFactor)");
    diag.writeln("");
    diag.writeln("Predicted travel: $predictedTravel min");
    if (isFallback) diag.writeln("⚠️ Estimate only (routing API unavailable)");
    diag.writeln("Safety buffer: $safetyBuffer min");
    diag.writeln("Required arrival: ${_formatTime(arriveAt)}");
    diag.writeln("");
    diag.writeln("Leave By: ${_formatTime(leaveBy)}");
    diag.writeln("Getting Ready: $gettingReadyTime min");
    diag.writeln("Ready At: ${_formatTime(readyAt)}");

    return TravelPrediction(
      mapplsDuration: mapplsDuration,
      weatherAdjustment: weatherAdjustment,
      predictedTravel: predictedTravel,
      safetyBuffer: safetyBuffer,
      gettingReadyTime: gettingReadyTime,
      leaveBy: leaveBy,
      readyAt: readyAt,
      arriveAt: arriveAt,
      diagnostics: diag.toString(),
      historyEstimate: history,
      isFallback: isFallback,
    );
  }

  static String _formatTime(DateTime dt) {
    int h = dt.hour;
    int m = dt.minute;
    String period = "AM";
    if (h >= 12) {
      period = "PM";
      if (h > 12) h -= 12;
    }
    if (h == 0) h = 12;
    return "$h:${m.toString().padLeft(2, '0')} $period";
  }
}
