import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'commute_model.dart';

class AddCommutePage extends StatefulWidget {
  final Function(Commute) onSave;
  final Commute? existingCommute;

  const AddCommutePage({super.key, required this.onSave, this.existingCommute});

  @override
  State<AddCommutePage> createState() => _AddCommutePageState();
}

class _AddCommutePageState extends State<AddCommutePage> {
  late TextEditingController _destinationController;
  late TimeOfDay _selectedTime;
  int _selectedMode = 0; // 0: Car, 1: Bike, 2: Train, 3: Flight
  bool _isPickup = false;
  List<String> _selectedDays = [];
  double? _lat;
  double? _lon;

  final List<String> _weekDays = ["M", "T", "W", "T", "F", "S", "S"];
  final List<String> _fullDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  @override
  void initState() {
    super.initState();
    _destinationController = TextEditingController(text: widget.existingCommute?.title ?? "");
    _selectedTime = _parseTime(widget.existingCommute?.time) ?? const TimeOfDay(hour: 8, minute: 30);
    _selectedDays = List.from(widget.existingCommute?.days ?? []);
    _lat = widget.existingCommute?.lat;
    _lon = widget.existingCommute?.lon;
    
    if (widget.existingCommute?.mode == 'motorcycle') _selectedMode = 1;
    else if (widget.existingCommute?.mode == 'train') _selectedMode = 2;
    else if (widget.existingCommute?.mode == 'flight') _selectedMode = 3;
    else _selectedMode = 0;

    if (widget.existingCommute != null && widget.existingCommute!.title.startsWith("Pick up: ")) {
      _isPickup = true;
      _destinationController.text = widget.existingCommute!.title.replaceFirst("Pick up: ", "");
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    try {
      final format = RegExp(r'(\d+):(\d+)\s+(AM|PM)');
      final match = format.firstMatch(timeStr);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        int minute = int.parse(match.group(2)!);
        if (match.group(3) == "PM" && hour < 12) hour += 12;
        if (match.group(3) == "AM" && hour == 12) hour = 0;
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return null;
  }

  Future<Iterable<Map<String, dynamic>>> _searchLocations(String query) async {
    if (query.length < 3) return const Iterable<Map<String, dynamic>>.empty();
    try {
      final response = await http.get(
        Uri.parse('https://photon.komoot.io/api/?q=$query&limit=5'),
        headers: {'User-Agent': 'ReachApp/1.0', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return (data['features'] as List).map((f) => {
          'name': f['properties']['name'] ?? "Unknown",
          'city': f['properties']['city'] ?? f['properties']['state'] ?? "",
          'lat': (f['geometry']['coordinates'][1] as num).toDouble(),
          'lon': (f['geometry']['coordinates'][0] as num).toDouble(),
        }).toList();
      }
    } catch (_) {}
    return const Iterable<Map<String, dynamic>>.empty();
  }

  void _submitData() {
    if (_destinationController.text.isEmpty) { _showError("Enter destination"); return; }
    if (_lat == null) { _showError("Select location from list"); return; }
    if (_selectedDays.isEmpty) { _showError("Select at least one day"); return; }

    String modeStr = 'car';
    if (_selectedMode == 1) modeStr = 'motorcycle';
    else if (_selectedMode == 2) modeStr = 'train';
    else if (_selectedMode == 3) modeStr = 'flight';

    String finalTitle = _isPickup && (_selectedMode > 1) 
        ? "Pick up: ${_destinationController.text}" 
        : _destinationController.text;

    widget.onSave(Commute(
      id: widget.existingCommute?.id, 
      title: finalTitle,
      time: _selectedTime.format(context),
      mode: modeStr,
      days: List<String>.from(_selectedDays),
      lat: _lat!,
      lon: _lon!,
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    // --- DYNAMIC THEME COLORS ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    // Input fields: Dark Grey in Dark Mode, Light Grey in Light Mode
    final inputColor = isDark ? Colors.grey[900] : Colors.grey[200]; 
    final hintColor = isDark ? Colors.grey : Colors.grey[600];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Adapts to settings
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existingCommute == null ? "New Trip" : "Edit Trip",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 30),
              
              Row(
                children: [
                  Expanded(child: AnimatedModeTile(label: "Car", icon: Icons.directions_car, isSelected: _selectedMode == 0, onTap: () => setState(() => _selectedMode = 0))),
                  const SizedBox(width: 8),
                  Expanded(child: AnimatedModeTile(label: "Bike", icon: Icons.two_wheeler, isSelected: _selectedMode == 1, onTap: () => setState(() => _selectedMode = 1))),
                  const SizedBox(width: 8),
                  Expanded(child: AnimatedModeTile(label: "Train", icon: Icons.train, isSelected: _selectedMode == 2, onTap: () => setState(() => _selectedMode = 2))),
                  const SizedBox(width: 8),
                  Expanded(child: AnimatedModeTile(label: "Flight", icon: Icons.flight, isSelected: _selectedMode == 3, onTap: () => setState(() => _selectedMode = 3))),
                ],
              ),
              
              const SizedBox(height: 20),

              if (_selectedMode >= 2) 
                _buildPickupToggle(isDark, inputColor!, textColor),

              const SizedBox(height: 20),

              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (option) => option['name'],
                optionsBuilder: (textValue) => _searchLocations(textValue.text),
                onSelected: (selection) => setState(() {
                  _destinationController.text = selection['name'];
                  _lat = selection['lat']; _lon = selection['lon'];
                }),
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  if (controller.text.isEmpty && _destinationController.text.isNotEmpty) {
                    controller.text = _destinationController.text;
                  }
                  return TextField(
                    controller: controller, focusNode: focusNode,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Destination (Station/Airport)",
                      hintStyle: TextStyle(color: hintColor),
                      filled: true, fillColor: inputColor,
                      prefixIcon: const Icon(Icons.search, color: Colors.orange),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  bool isSelected = _selectedDays.contains(_fullDays[index]);
                  return GestureDetector(
                    onTap: () => setState(() => isSelected ? _selectedDays.remove(_fullDays[index]) : _selectedDays.add(_fullDays[index])),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.orange[800] : inputColor, 
                        shape: BoxShape.circle
                      ),
                      alignment: Alignment.center,
                      child: Text(_weekDays[index], style: TextStyle(color: isSelected ? Colors.white : hintColor)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30),

              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                  if (picked != null) setState(() => _selectedTime = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    const Icon(Icons.access_time_filled, color: Colors.orange),
                    const SizedBox(width: 15),
                    Text(_selectedTime.format(context), style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  onPressed: _submitData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("Set Alert", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickupToggle(bool isDark, Color inputColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(_isPickup ? Icons.person_pin_circle : Icons.flight_takeoff, color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              Text(_isPickup ? "Picking someone up" : "Catching the trip", 
                style: TextStyle(color: textColor, fontSize: 14)),
            ],
          ),
          Switch(
            value: _isPickup,
            onChanged: (val) => setState(() => _isPickup = val),
            activeColor: Colors.orange,
          ),
        ],
      ),
    );
  }
}

// --- ANIMATED TILE WIDGET (THEME AWARE) ---
class AnimatedModeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const AnimatedModeTile({
    super.key, 
    required this.label, 
    required this.icon, 
    required this.isSelected, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Unselected color: Grey[900] (Dark) vs Grey[200] (Light)
    final unselectedColor = isDark ? Colors.grey[900] : Colors.grey[200];
    final unselectedIconColor = isDark ? Colors.grey : Colors.grey[600];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[800] : unselectedColor,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.orange, width: 1) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : unselectedIconColor, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : unselectedIconColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 10
              ),
            ),
          ],
        ),
      ),
    );
  }
}