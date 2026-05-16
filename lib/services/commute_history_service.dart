import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two-tier personalized learning engine for Reach.
///
/// TIER 1 — GLOBAL (cross-commute): Tracks the user's general lateness habit
///   across ALL commutes. Captures things like slow preparation, parking
///   delays, walking speed, general tendency to leave late.
///
/// TIER 2 — COMMUTE-SPECIFIC: Tracks route-specific delays for each commute
///   independently (e.g. college traffic unpredictability, office parking).
///
/// FORMULA (applied in _saveCommute):
///   adaptiveBuffer = (globalAvg + commuteAvg).clamp(0, 15)
///   trafficBuffer  += adaptiveBuffer
///
/// ROLLING WINDOW: last 7 outcomes only — older data is discarded so the
///   system adapts to current behavior, not stale history.
///
/// CAP: Combined adaptive buffer is hard-capped at 15 minutes to prevent
///   unstable schedules from single outlier trips.
class CommuteHistoryService {
  // ── Storage keys ──────────────────────────────────────────────────────────
  static const String _commuteHistoryPrefix = 'reach_history_';
  static const String _commuteBufferPrefix  = 'reach_cbuffer_';
  static const String _globalHistoryKey     = 'reach_global_history';
  static const String _globalBufferKey      = 'reach_global_buffer';

  // ── Parameters ────────────────────────────────────────────────────────────
  static const int _rollingWindow    = 7;  // keep only last 7 outcomes
  static const int _minDataPoints    = 3;  // need at least 3 before adjusting
  static const int _maxAdaptiveBuffer = 15; // hard cap: global + commute ≤ 15 min

  // ── PUBLIC: Save outcome ──────────────────────────────────────────────────

  /// Record one commute session result and update both learning tiers.
  ///
  /// [outcome]      — 'reached' | 'almost' | 'unknown'
  /// [delayMinutes] — positive = arrived late, negative = arrived early.
  ///                  For 'almost' responses this is a fixed +10.
  static Future<void> saveOutcome({
    required String commuteId,
    required String outcome,
    required int delayMinutes,
  }) async {
    if (outcome == 'unknown') return; // don't pollute averages with no-ops

    try {
      final prefs = await SharedPreferences.getInstance();

      // ── Tier 2: Commute-specific ──
      await _appendAndTrim(
        prefs,
        key: '$_commuteHistoryPrefix$commuteId',
        entry: _entry(outcome, delayMinutes),
      );
      await _recomputeBuffer(
        prefs,
        historyKey: '$_commuteHistoryPrefix$commuteId',
        bufferKey:  '$_commuteBufferPrefix$commuteId',
        label: 'commute($commuteId)',
      );

      // ── Tier 1: Global (all commutes) ──
      await _appendAndTrim(
        prefs,
        key: _globalHistoryKey,
        entry: _entry(outcome, delayMinutes),
      );
      await _recomputeBuffer(
        prefs,
        historyKey: _globalHistoryKey,
        bufferKey:  _globalBufferKey,
        label: 'global',
      );

      debugPrint('[LEARN] saveOutcome | id=$commuteId | outcome=$outcome | delay=$delayMinutes min');
    } catch (e) {
      debugPrint('[LEARN] saveOutcome error: $e');
    }
  }

  // ── PUBLIC: Get combined capped buffer ────────────────────────────────────

  /// Returns the adaptive buffer to add to the base traffic buffer.
  ///
  ///   result = (globalAvg + commuteAvg).clamp(0, 15)
  ///
  /// Returns 0 if there are fewer than [_minDataPoints] sessions in either
  /// tier — avoids over-correcting too early.
  static Future<int> getLearnedBuffer(String commuteId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final globalBuffer  = prefs.getInt(_globalBufferKey) ?? 0;
      final commuteBuffer = prefs.getInt('$_commuteBufferPrefix$commuteId') ?? 0;

      final combined = (globalBuffer + commuteBuffer).clamp(0, _maxAdaptiveBuffer);

      debugPrint('[LEARN] getLearnedBuffer | id=$commuteId '
          '| global=$globalBuffer min | commute=$commuteBuffer min '
          '| combined=$combined min (cap=$_maxAdaptiveBuffer)');

      return combined;
    } catch (e) {
      debugPrint('[LEARN] getLearnedBuffer error: $e');
      return 0;
    }
  }

  // ── PUBLIC: Debug / inspection ────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCommuteHistory(String commuteId) async {
    final prefs = await SharedPreferences.getInstance();
    return _load(prefs.getString('$_commuteHistoryPrefix$commuteId'));
  }

  static Future<List<Map<String, dynamic>>> getGlobalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return _load(prefs.getString(_globalHistoryKey));
  }

  // ── PUBLIC: Cleanup ───────────────────────────────────────────────────────

  /// Clears commute-specific data when a commute is deleted.
  /// Global history is intentionally preserved — it reflects the user's
  /// overall habits regardless of which commutes exist.
  static Future<void> clearHistory(String commuteId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_commuteHistoryPrefix$commuteId');
      await prefs.remove('$_commuteBufferPrefix$commuteId');
      debugPrint('[LEARN] Cleared commute-specific history | id=$commuteId');
    } catch (e) {
      debugPrint('[LEARN] clearHistory error: $e');
    }
  }

  // ── PRIVATE helpers ───────────────────────────────────────────────────────

  static Map<String, dynamic> _entry(String outcome, int delayMinutes) => {
    'outcome': outcome,
    'delayMinutes': delayMinutes,
    'ts': DateTime.now().millisecondsSinceEpoch,
  };

  /// Appends [entry] to the JSON list stored at [key] and trims to the last
  /// [_rollingWindow] entries. Oldest entries are dropped automatically.
  static Future<void> _appendAndTrim(
    SharedPreferences prefs, {
    required String key,
    required Map<String, dynamic> entry,
  }) async {
    List<Map<String, dynamic>> list = _load(prefs.getString(key));
    list.add(entry);
    if (list.length > _rollingWindow) {
      list = list.sublist(list.length - _rollingWindow);
    }
    await prefs.setString(key, json.encode(list));
  }

  /// Recomputes the average delay from [historyKey] and writes it to
  /// [bufferKey]. Writes 0 if fewer than [_minDataPoints] entries exist.
  static Future<void> _recomputeBuffer(
    SharedPreferences prefs, {
    required String historyKey,
    required String bufferKey,
    required String label,
  }) async {
    final list = _load(prefs.getString(historyKey));

    if (list.length < _minDataPoints) {
      debugPrint('[LEARN] $label: ${list.length}/$_minDataPoints points — buffer unchanged');
      // Don't write 0 here: preserve any previously computed value until
      // enough new data arrives to overwrite it.
      return;
    }

    final delays = list
        .map((e) => (e['delayMinutes'] as num).toInt())
        .toList();

    final avg = delays.reduce((a, b) => a + b) / delays.length;

    // Clamp to [0, _maxAdaptiveBuffer]. Negative averages (user consistently
    // early) don't reduce the base buffer — the traffic API already handles
    // that; we just don't add unnecessary time.
    final buffer = avg.round().clamp(0, _maxAdaptiveBuffer);

    await prefs.setInt(bufferKey, buffer);
    debugPrint('[LEARN] $label buffer updated | '
        'window=${list.length} | avgDelay=${avg.toStringAsFixed(1)} min | buffer=$buffer min');
  }

  static List<Map<String, dynamic>> _load(String? raw) {
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(json.decode(raw));
    } catch (_) {
      return [];
    }
  }
}
