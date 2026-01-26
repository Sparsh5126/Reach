import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  final String _apiKey = "YOUR_OPENWEATHER_KEY"; // Ensure you have your key here

  Future<double> getWeatherBuffer(double lat, double lon, String mode) async {
    try {
      final url = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String weather = data['weather'][0]['main'].toString().toLowerCase();

        double baseBuffer = 0.0;
        if (weather.contains('rain') || weather.contains('drizzle')) {
          baseBuffer = 15.0;
        } else if (weather.contains('snow') || weather.contains('storm')) {
          baseBuffer = 30.0;
        }

        // BIKER LOGIC: Double the buffer if on a motorcycle
        if (mode == 'motorcycle') {
          return baseBuffer * 2.0;
        }
        return baseBuffer;
      }
    } catch (e) {
      return 0.0;
    }
    return 0.0;
  }
}