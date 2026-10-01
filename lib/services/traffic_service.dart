import 'dart:math';
import 'package:flutter/foundation.dart';
import 'route_service.dart';

/// Holds a travel-time result with metadata about how it was obtained.
class TrafficResult {
  final int duration;

  /// True when the duration is a distance-based estimate rather than
  /// a real routing-API result.  The UI should mark these values as
  /// approximate so the user knows they are not precise.
  final bool isFallback;

  const TrafficResult(this.duration, {this.isFallback = false});
}

// Simple class to hold data + timestamp
class _TrafficCacheItem {
  final int duration;
  final DateTime timestamp;
  _TrafficCacheItem(this.duration, this.timestamp);
}

class TrafficService {
  // STATIC MEMORY CACHE — shared across all instances
  static final Map<String, _TrafficCacheItem> _cache = {};
  static const int _cacheDurationMinutes = 5;

  /// Decimal places the *origin* is bucketed to in the cache key.
  ///
  /// 3 places is ~110 m, which is below the noise floor of a
  /// LocationAccuracy.medium fix and well under a minute of travel. This was 4
  /// places (~11 m): every app resume produced a slightly different fix, so
  /// each one minted fresh keys for every commute and re-hit the routing API
  /// even when the last answer was seconds old. Only the origin is bucketed —
  /// the destination stays exact, since two destinations must never collide.
  static const int _originKeyPrecision = 3;

  Future<TrafficResult> getMapplsDuration(
    double startLat,
    double startLon,
    String? destELoc, {
    double? destLat,
    double? destLon,
    String? mode,
  }) async {
    String? destination;
    // RouteService's Direction endpoint accepts either a "lon,lat" pair or a
    // bare eLoc as a waypoint, so both branches below reach the real routing
    // API. Prefer stored coordinates when present (one less thing for Mappls
    // to resolve); fall back to the eLoc otherwise — which is the common case,
    // since the Atlas autosuggest response AddEditSheet saves from carries no
    // latitude/longitude fields, leaving Commute.lat/lon at 0.0.
    if (destLon != null &&
        destLon != 0.0 &&
        destLat != null &&
        destLat != 0.0) {
      destination = "$destLon,$destLat";
    } else if (destELoc != null && destELoc.trim().isNotEmpty) {
      destination = destELoc.trim();
    }

    if (destination == null) {
      debugPrint("REACH APP: Traffic -> no destination coordinates available");
      return const TrafficResult(20, isFallback: true);
    }

    // Include eLoc in the cache key so that commutes with the same rounded
    // coordinates but different destinations don't collide in the cache.
    final String cacheKey =
        "${startLat.toStringAsFixed(_originKeyPrecision)}_${startLon.toStringAsFixed(_originKeyPrecision)}_${mode ?? 'car'}_${destELoc ?? destination}";

    final cached = _cache[cacheKey];
    if (cached != null) {
      final age = DateTime.now().difference(cached.timestamp).inMinutes;
      if (age < _cacheDurationMinutes) {
        return TrafficResult(cached.duration);
      }
    }

    try {
      final durationMinutes = await RouteService.getTravelTime(
        startLat: startLat,
        startLon: startLon,
        destination: destination,
        mode: mode ?? 'car',
      );

      if (durationMinutes != null && durationMinutes > 0) {
        _store(cacheKey, durationMinutes);
        return TrafficResult(durationMinutes);
      }
    } catch (e) {
      debugPrint("REACH APP: Traffic fetch error -> $e");
    }

    // Serve stale cache if API fails rather than returning an estimate.
    // NOTE: this is why expired entries are kept rather than pruned — an old
    // real measurement beats a synthetic guess. _store() bounds the map by
    // size instead.
    // Re-read rather than reusing the pre-await snapshot, in case a concurrent
    // caller populated this key while the request above was in flight.
    final stale = _cache[cacheKey];
    if (stale != null) {
      return TrafficResult(stale.duration);
    }

    // Distance-based estimate as last resort (replaces old hardcoded 35).
    // (0,0) is never a real current-location fix (it's off the coast of
    // Africa) — it means GPS/last-known-location hasn't loaded yet. Treating
    // it as a real origin turns a missing location into a several-thousand-km
    // haversine distance, i.e. a multi-day "travel time". Bail to a generic
    // estimate instead of propagating that nonsense downstream.
    final bool hasValidOrigin = startLat != 0.0 || startLon != 0.0;
    if (!hasValidOrigin) {
      debugPrint("REACH APP: Traffic fallback -> no origin location yet, using generic estimate");
      return const TrafficResult(20, isFallback: true);
    }

    // Same issue on the destination side: destLat/destLon default to 0.0
    // (not null) on a Commute that only has an eLoc and no resolved
    // coordinates, so `destLat ?? startLat` never substitutes — it silently
    // passes (0,0) through as a "real" destination, producing a haversine
    // distance to the Gulf of Guinea instead of bailing out.
    final bool hasValidDest =
        (destLat != null && destLat != 0.0) || (destLon != null && destLon != 0.0);
    if (!hasValidDest) {
      debugPrint("REACH APP: Traffic fallback -> no resolved destination coordinates, using generic estimate");
      return const TrafficResult(20, isFallback: true);
    }

    final fallbackMinutes = _haversineEstimate(
      startLat, startLon,
      destLat!, destLon!,
      mode ?? 'car',
    );
    debugPrint(
      "REACH APP: Traffic fallback -> haversine estimate = ${fallbackMinutes}min "
      "(origin=$startLat,$startLon dest=$destLat,$destLon mode=${mode ?? 'car'})",
    );
    return TrafficResult(fallbackMinutes, isFallback: true);
  }

  // No clearCache() here on purpose. The old one was called once, from main(),
  // to "clear stale cache from previous sessions" — but _cache is an in-memory
  // static, so it is already empty at process start and that call was a no-op.
  // Nothing else needs it either: origin, mode and destination are all part of
  // the cache key, so a change to any of them lands on a different entry rather
  // than reading a stale one.

  /// Upper bound on cache entries. Expired entries are intentionally retained
  /// to back the stale-serve path above, so the map needs a size ceiling
  /// rather than a TTL sweep. Realistically it holds (origin buckets ×
  /// destinations × modes), which stays small; this only guards the pathological
  /// case of a long-running process visiting many origins.
  static const int _maxCacheEntries = 64;

  static void _store(String key, int durationMinutes) {
    if (!_cache.containsKey(key) && _cache.length >= _maxCacheEntries) {
      // Evict the oldest entry, keeping the most recent ones available as
      // stale fallbacks.
      String? oldestKey;
      DateTime? oldest;
      for (final e in _cache.entries) {
        if (oldest == null || e.value.timestamp.isBefore(oldest)) {
          oldest = e.value.timestamp;
          oldestKey = e.key;
        }
      }
      if (oldestKey != null) _cache.remove(oldestKey);
    }
    _cache[key] = _TrafficCacheItem(durationMinutes, DateTime.now());
  }

  // ── Haversine distance-based estimate ──────────────────────────────────────
  // Calculates straight-line distance, applies a road detour factor, and
  // divides by a mode-specific average urban speed.  This is imprecise but
  // proportional to actual distance — much better than a constant.

  static int _haversineEstimate(
    double lat1, double lon1,
    double lat2, double lon2,
    String mode,
  ) {
    // If origin ≈ destination (e.g. GPS fell back to dest coords), the
    // distance is meaningless.  Return a generic urban commute estimate.
    if ((lat1 - lat2).abs() < 0.001 && (lon1 - lon2).abs() < 0.001) {
      return 20;
    }

    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final straightKm = earthRadiusKm * c;

    // Roads are ~1.3× longer than straight-line distance in urban areas.
    final effectiveKm = straightKm * 1.3;

    // Average urban speeds by mode (km/h)
    final speedKmh = switch (mode) {
      'motorcycle' => 30.0,
      _ => 25.0, // car / transit road speed in city traffic
    };

    return max(1, (effectiveKm / speedKmh * 60).round());
  }

  static double _toRad(double deg) => deg * pi / 180;
}
