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
  bool _isPickup = false; // The missing toggle
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
    
    // Restore mode and pickup status
    if (widget.existingCommute?.mode == 'motorcycle') _selectedMode = 1;
    else if (widget.existingCommute?.mode == 'train') _selectedMode = 2;
    else if (widget.existingCommute?.mode == 'flight') _selectedMode = 3;
    else _selectedMode = 0;
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

    // Combine mode and pickup info for the logic
    String finalTitle = _isPickup && (_selectedMode > 1) 
        ? "Pick up: ${_destinationController.text}" 
        : _destinationController.text;

    widget.onSave(Commute(
      title: finalTitle,
      time: _selectedTime.format(context),
      mode: modeStr,
      days: _selectedDays,
      lat: _lat!,
      lon: _lon!,
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existingCommute == null ? "New Trip" : "Edit Trip",
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 30),
              
              // MODE SELECTOR
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    _buildModeBtn("Car", Icons.directions_car, 0),
                    _buildModeBtn("Bike", Icons.motorcycle, 1),
                    _buildModeBtn("Train", Icons.train, 2),
                    _buildModeBtn("Flight", Icons.flight, 3),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // DYNAMIC PICKUP TOGGLE
              if (_selectedMode >= 2) 
                _buildPickupToggle(),

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
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Destination (Station/Airport)",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true, fillColor: Colors.grey[900],
                      prefixIcon: const Icon(Icons.search, color: Colors.orange),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              
              // DAY SELECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  bool isSelected = _selectedDays.contains(_fullDays[index]);
                  return GestureDetector(
                    onTap: () => setState(() => isSelected ? _selectedDays.remove(_fullDays[index]) : _selectedDays.add(_fullDays[index])),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: isSelected ? Colors.orange[800] : Colors.grey[900], shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(_weekDays[index], style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
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
                  decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    const Icon(Icons.access_time_filled, color: Colors.orange),
                    const SizedBox(width: 15),
                    Text(_selectedTime.format(context), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _buildPickupToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(_isPickup ? Icons.person_pin_circle : Icons.flight_takeoff, color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              Text(_isPickup ? "Picking someone up" : "Catching the trip", 
                style: const TextStyle(color: Colors.white, fontSize: 14)),
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

  Widget _buildModeBtn(String label, IconData icon, int index) {
    bool isSelected = _selectedMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? Colors.orange[800] : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}