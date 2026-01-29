import 'package:uuid/uuid.dart';

class Commute {
  final String id;
  final String title;
  final String time; 
  final String mode;
  final List<String> days; 
  final double lat;
  final double lon;

  Commute({
    String? id,
    required this.title,
    required this.time,
    required this.mode,
    required this.days,
    this.lat = 0.0,
    this.lon = 0.0,
  }) : id = id ?? const Uuid().v4();

  int get timeInMinutes {
    final match = RegExp(r'(\d+):(\d+)\s+(AM|PM)').firstMatch(time);
    if (match == null) return 0;
    int h = int.parse(match.group(1)!);
    int m = int.parse(match.group(2)!);
    if (match.group(3) == "PM" && h < 12) h += 12;
    if (match.group(3) == "AM" && h == 12) h = 0;
    return h * 60 + m;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 
    'title': title, 'time': time, 'mode': mode, 
    'days': days, 'lat': lat, 'lon': lon,
  };

  factory Commute.fromJson(Map<String, dynamic> json) => Commute(
    id: json['id'], 
    title: json['title'], time: json['time'], mode: json['mode'],
    days: List<String>.from(json['days'] ?? []), lat: json['lat'], lon: json['lon'],
  );
}