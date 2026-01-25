import 'dart:convert';

class Commute {
  final String id;
  final String destination;
  final String arrivalTime;
  final List<String> days;
  final int durationMinutes;
  final String transportMode;
  final double? latitude;
  final double? longitude;

  Commute({
    required this.id,
    required this.destination,
    required this.arrivalTime,
    required this.days,
    required this.durationMinutes,
    required this.transportMode,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination': destination,
      'arrivalTime': arrivalTime,
      'days': days,
      'durationMinutes': durationMinutes,
      'transportMode': transportMode,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Commute.fromJson(Map<String, dynamic> json) {
    return Commute(
      id: json['id'],
      destination: json['destination'],
      arrivalTime: json['arrivalTime'],
      days: List<String>.from(json['days']),
      durationMinutes: json['durationMinutes'] ?? 30,
      transportMode: json['transportMode'] ?? 'driving',
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }

  static String encode(List<Commute> commutes) => json.encode(
        commutes.map<Map<String, dynamic>>((c) => c.toJson()).toList(),
      );

  static List<Commute> decode(String commutes) =>
      (json.decode(commutes) as List<dynamic>)
          .map<Commute>((item) => Commute.fromJson(item))
          .toList();
}