import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  final String baseUrl = "https://api.open-meteo.com/v1/forecast";

  /// Returns { 'factor': 1.0, 'emoji': '⛈️' }
  Future<Map<String, dynamic>> getWeatherInfo(double lat, double lon) async {
    try {
      final url = Uri.parse('$baseUrl?latitude=$lat&longitude=$lon&current_weather=true');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final int code = data['current_weather']['weathercode'];
        
        // --- WEATHER CODE MAPPING ---
        if (code >= 95 && code <= 99) {
          return {'factor': 2.0, 'emoji': '⛈️'}; // Storm (100% delay)
        } else if (code >= 61 && code <= 67) {
          return {'factor': 1.5, 'emoji': '🌧️'}; // Rain (50% delay)
        } else if (code >= 51 && code <= 57) {
          return {'factor': 1.3, 'emoji': '🌦️'}; // Drizzle (30% delay)
        } else if (code >= 71 && code <= 77) {
          return {'factor': 2.0, 'emoji': '❄️'}; // Snow (100% delay)
        } else if (code >= 1 && code <= 3) {
          return {'factor': 1.0, 'emoji': '☁️'}; // Cloudy (0% delay)
        } else {
          return {'factor': 1.0, 'emoji': '☀️'}; // Clear (Default)
        }
      }
    } catch (e) {
      print("⚠️ Weather API Error: $e");
    }
    return {'factor': 1.0, 'emoji': ''}; // Return default 1.0 if failed
  }
}