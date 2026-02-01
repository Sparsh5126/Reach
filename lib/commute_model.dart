import 'dart:convert';
import 'package:uuid/uuid.dart';

class Commute {
  final String id;
  final String title;
  final String time; 
  final String mode; 
  final List<String> days; 
  final double lat;
  final double lon;
  final String? eLoc;

  Commute({
    String? id,
    required this.title,
    required this.time,
    required this.mode,
    required this.days,
    required this.lat,
    required this.lon,
    this.eLoc,
  }) : id = id ?? const Uuid().v4();

  int get timeInMinutes {
    try {
      final parts = time.split(" ");
      final hm = parts[0].split(":");
      int h = int.parse(hm[0]);
      int m = int.parse(hm[1]);
      if (parts[1] == "PM" && h != 12) h += 12;
      if (parts[1] == "AM" && h == 12) h = 0;
      return h * 60 + m;
    } catch (e) {
      return 0;
    }
  }

  // --- 1. TO MAP (Used for Saving) ---
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'time': time,
      'mode': mode,
      'days': days,
      'lat': lat,
      'lon': lon,
      'eLoc': eLoc,
    };
  }

  // --- 2. FROM MAP (Used for Loading) ---
  factory Commute.fromMap(Map<String, dynamic> map) {
    return Commute(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      time: map['time'] ?? '',
      mode: map['mode'] ?? 'car',
      days: List<String>.from(map['days'] ?? []),
      lat: map['lat']?.toDouble() ?? 0.0,
      lon: map['lon']?.toDouble() ?? 0.0,
      eLoc: map['eLoc'],
    );
  }

  String toJson() => json.encode(toMap());

  // --- 3. FLEXIBLE DECODER (Fixes the crash) ---
  factory Commute.fromJson(dynamic source) {
    if (source is String) {
      return Commute.fromMap(json.decode(source));
    } else if (source is Map<String, dynamic>) {
      return Commute.fromMap(source);
    } else {
      throw Exception("Unknown type for Commute.fromJson");
    }
  }
}