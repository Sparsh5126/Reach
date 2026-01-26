class Commute {
  final String title;
  final String time; 
  final String mode;
  final List<String> days; 
  final double lat;
  final double lon;

  Commute({
    required this.title,
    required this.time,
    required this.mode,
    required this.days,
    this.lat = 0.0,
    this.lon = 0.0,
  });

  int get timeInMinutes {
    final format = RegExp(r'(\d+):(\d+)\s+(AM|PM)');
    final match = format.firstMatch(time);
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      int minute = int.parse(match.group(2)!);
      if (match.group(3) == "PM" && hour < 12) hour += 12;
      if (match.group(3) == "AM" && hour == 12) hour = 0;
      return hour * 60 + minute;
    }
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'title': title, 'time': time, 'mode': mode, 
    'days': days, 'lat': lat, 'lon': lon,
  };

  factory Commute.fromJson(Map<String, dynamic> json) => Commute(
    title: json['title'], time: json['time'], mode: json['mode'],
    days: List<String>.from(json['days']), lat: json['lat'], lon: json['lon'],
  );
}