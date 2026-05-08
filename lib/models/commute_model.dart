class Commute {
  final String id;
  final String title;       // This is the Address/Location Name
  final String? customTitle; // User's nickname ("Work", "Gym")
  final String time;
  final String mode;
  final List<String> days;
  final double lat;
  final double lon;
  final String? eLoc;
  final bool isFavorite;     // Pin to top

  Commute({
    required this.id,
    required this.title,
    this.customTitle,
    required this.time,
    required this.mode,
    required this.days,
    required this.lat,
    required this.lon,
    this.eLoc,
    this.isFavorite = false,
  });

  // Convert to Map for saving
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'customTitle': customTitle,
      'time': time,
      'mode': mode,
      'days': days,
      'lat': lat,
      'lon': lon,
      'eLoc': eLoc,
      'isFavorite': isFavorite ? 1 : 0, // Save boolean as int
    };
  }

  // Create from Map for loading
  factory Commute.fromJson(Map<String, dynamic> map) {
    return Commute(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Unknown',
      customTitle: map['customTitle']?.toString(),
      time: map['time']?.toString() ?? '09:00 AM',
      mode: map['mode']?.toString() ?? 'car',
      days: map['days'] != null ? List<String>.from(map['days']) : [],
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (map['lon'] as num?)?.toDouble() ?? 0.0,
      eLoc: map['eLoc']?.toString(),
      isFavorite: map['isFavorite'] == 1 || map['isFavorite'] == true, 
    );
  }

  // Helper to copy object
  Commute copyWith({
    String? title,
    String? customTitle,
    String? time,
    String? mode,
    List<String>? days,
    double? lat,
    double? lon,
    String? eLoc,
    bool? isFavorite,
  }) {
    return Commute(
      id: id,
      title: title ?? this.title,
      customTitle: customTitle ?? this.customTitle,
      time: time ?? this.time,
      mode: mode ?? this.mode,
      days: days ?? this.days,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      eLoc: eLoc ?? this.eLoc,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // Helper to calculate minutes for sorting
  int get timeInMinutes {
    final t = time.replaceAll(RegExp(r'[^\d:APM]'), ''); 
    final parts = t.split(":");
    int h = int.parse(parts[0]);
    int m = int.parse(parts[1].substring(0, 2));
    final isPm = t.contains("PM");
    if (isPm && h != 12) h += 12;
    if (!isPm && h == 12) h = 0;
    return h * 60 + m;
  }
}