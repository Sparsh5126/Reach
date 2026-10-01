import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryEstimate {
  final int predictedMinutes;
  final String tier;
  final int sampleCount;
  final String explanation;

  HistoryEstimate({
    required this.predictedMinutes,
    required this.tier,
    required this.sampleCount,
    required this.explanation,
  });
}

class CommuteHistoryService {
  static const String _commuteHistoryPrefix = 'reach_travel_history_';

  static const int _windowSize = 12; // Keep last 12 trips

  // A single-leg local commute realistically never takes longer than this.
  // notifHandleCheckin() measures actualMinutes as wall-clock time between a
  // stored "departed" timestamp and whenever "Reached" gets tapped — a stale
  // or dismissed-then-late-tapped check-in notification (or a depart marker
  // that never got cleared) can turn that into thousands of minutes. Without
  // this guard, one such tap permanently pollutes the learned median.
  static const int _maxSaneMinutes = 240;

  // ── PUBLIC: Record actual travel time ──────────────────────────────────────

  /// Records the actual time taken from departure to arrival.
  static Future<void> recordActualTravel({
    required String commuteId,
    required String mode,
    required int actualMinutes,
    required int mapplsMinutes,
  }) async {
    if (actualMinutes <= 0 || actualMinutes > _maxSaneMinutes) {
      debugPrint('[LEARN] Discarding implausible trip duration: actual=$actualMinutes min (id=$commuteId, mode=$mode)');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_commuteHistoryPrefix${commuteId}_$mode';

      List<Map<String, dynamic>> list = _load(prefs.getString(key));

      list.add({
        'actualMinutes': actualMinutes,
        'mapplsMinutes': mapplsMinutes,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Keep bounded window
      if (list.length > _windowSize) {
        list = list.sublist(list.length - _windowSize);
      }
      
      await prefs.setString(key, json.encode(list));
      debugPrint('[LEARN] Recorded trip: id=$commuteId | mode=$mode | actual=$actualMinutes | mappls=$mapplsMinutes');
    } catch (e) {
      debugPrint('[LEARN] recordActualTravel error: $e');
    }
  }

  // ── PUBLIC: Predict travel time ───────────────────────────────────────────

  /// Predicts travel time using the robust median of past trips, depending on data tiers.
  static Future<HistoryEstimate> getPredictedTravel({
    required String commuteId,
    required String mode,
    required int mapplsMinutes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_commuteHistoryPrefix${commuteId}_$mode';
      // Filter out any already-stored implausible samples (e.g. recorded
      // before this guard existed) so old corrupted data can't keep dragging
      // the median off — see _maxSaneMinutes.
      final list = _load(prefs.getString(key))
          .where((e) {
            final actual = (e['actualMinutes'] as num?)?.toInt() ?? 0;
            return actual > 0 && actual <= _maxSaneMinutes;
          })
          .toList();

      final int sampleCount = list.length;
      
      if (sampleCount <= 2) {
        // No history tier
        return HistoryEstimate(
          predictedMinutes: mapplsMinutes,
          tier: 'No history',
          sampleCount: sampleCount,
          explanation: 'Insufficient data. Using standard routing.',
        );
      }
      
      // Compute robust median of actual travel times
      final actuals = list.map((e) => (e['actualMinutes'] as num).toInt()).toList();
      actuals.sort();
      final int medianActual = actuals[actuals.length ~/ 2];
      
      if (sampleCount <= 9) {
        // Some history tier: Blend Mappls and History
        // Weight goes from 0.3 (at 3 trips) to 0.9 (at 9 trips)
        double historyWeight = sampleCount / 10.0;
        int blended = (medianActual * historyWeight + mapplsMinutes * (1 - historyWeight)).round();
        
        return HistoryEstimate(
          predictedMinutes: blended,
          tier: 'Some history',
          sampleCount: sampleCount,
          explanation: 'Blended standard routing with limited past trips.',
        );
      } else {
        // Strong history tier
        // Use median, but allow Mappls to influence if it predicts an unusually high duration 
        // (e.g. major accident). If Mappls > median, we assume there's a reason.
        int predicted = medianActual;
        if (mapplsMinutes > medianActual + 5) {
          // If Mappls is significantly higher, blend heavily towards Mappls to reflect current conditions
          predicted = (medianActual * 0.3 + mapplsMinutes * 0.7).round();
        }
        
        return HistoryEstimate(
          predictedMinutes: predicted,
          tier: 'Strong history',
          sampleCount: sampleCount,
          explanation: 'Based heavily on your personalized history.',
        );
      }
      
    } catch (e) {
      debugPrint('[LEARN] getPredictedTravel error: $e');
      return HistoryEstimate(
        predictedMinutes: mapplsMinutes,
        tier: 'Error',
        sampleCount: 0,
        explanation: 'Fallback to routing due to error.',
      );
    }
  }

  // ── PUBLIC: Debug / inspection ────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getTravelHistory(String commuteId, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    return _load(prefs.getString('$_commuteHistoryPrefix${commuteId}_$mode'));
  }

  static Future<void> clearHistory(String commuteId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('$_commuteHistoryPrefix$commuteId')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// Removes the recorded trips for every commute. Touches only history keys.
  static Future<void> clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_commuteHistoryPrefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  // ── PRIVATE helpers ───────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _load(String? raw) {
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(json.decode(raw));
    } catch (_) {
      return [];
    }
  }
}
