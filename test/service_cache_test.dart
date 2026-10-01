import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reach/services/weather_service.dart';

void main() {
  int requestCount = 0;
  bool shouldFail = false;

  /// Answers from memory and counts calls, so these tests assert on caching
  /// behaviour rather than on the live Open-Meteo service.
  WeatherService subject() => WeatherService(
        client: MockClient((http.Request req) async {
          requestCount++;
          if (shouldFail) return http.Response('upstream error', 500);
          // weathercode 0 maps to the "Clear" branch.
          return http.Response(
            json.encode({'current_weather': {'weathercode': 0}}),
            200,
          );
        }),
      );

  setUp(() {
    requestCount = 0;
    shouldFail = false;
    WeatherService.clearCache();
  });

  test('concurrent lookups share a single in-flight request', () async {
    final a = subject().getWeatherInfo(28.6139, 77.2090);
    final b = subject().getWeatherInfo(28.6139, 77.2090);

    expect(identical(a, b), isTrue, reason: 'should reuse the pending Future');
    await Future.wait([a, b]);
    expect(requestCount, 1);
  });

  test('a repeat lookup inside the TTL does not hit the network', () async {
    final first = await subject().getWeatherInfo(28.6139, 77.2090);
    expect(first['emoji'], '☀️');
    expect(requestCount, 1);

    await subject().getWeatherInfo(28.6139, 77.2090);
    expect(requestCount, 1, reason: 'second call should be served from cache');
  });

  test('nearby coordinates share a bucket, distant ones do not', () async {
    // ~300 m apart — the same ~1.1 km bucket.
    await subject().getWeatherInfo(28.6139, 77.2090);
    await subject().getWeatherInfo(28.6141, 77.2093);
    expect(requestCount, 1);

    // Dehradun is a different bucket and must be fetched.
    await subject().getWeatherInfo(30.3165, 78.0322);
    expect(requestCount, 2);
  });

  test('a failed lookup is evicted rather than pinned for the TTL', () async {
    shouldFail = true;
    final failed = await subject().getWeatherInfo(28.6139, 77.2090);
    expect(failed['emoji'], '', reason: 'failure returns the neutral fallback');
    expect(failed['factor'], 1.0);
    expect(requestCount, 1);

    // Recovered service: the next call must retry instead of replaying the
    // cached failure for the rest of the TTL.
    shouldFail = false;
    final retried = await subject().getWeatherInfo(28.6139, 77.2090);
    expect(requestCount, 2, reason: 'a failure must not occupy the slot');
    expect(retried['emoji'], '☀️');
  });
}
