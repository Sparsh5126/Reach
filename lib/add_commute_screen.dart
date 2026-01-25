import 'package:flutter/material.dart';
import 'commute_model.dart';
import 'location_service.dart';
import 'route_service.dart';

class AddCommuteScreen extends StatefulWidget {
  final Commute? commuteToEdit;

  const AddCommuteScreen({super.key, this.commuteToEdit});

  @override
  State<AddCommuteScreen> createState() => _AddCommuteScreenState();
}

class _AddCommuteScreenState extends State<AddCommuteScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _destController = TextEditingController();
  TimeOfDay _arrivalTime = const TimeOfDay(hour: 9, minute: 0);
  final List<String> _selectedDays = [];
  final List<String> _daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  String _transportMode = 'driving';
  int _durationMinutes = 30;
  bool _isSearching = false;
  List<LocationResult> _searchResults = [];
  double? _selectedLat;
  double? _selectedLon;

  @override
  void initState() {
    super.initState();
    if (widget.commuteToEdit != null) {
      final c = widget.commuteToEdit!;
      _destController.text = c.destination;
      _arrivalTime = _parseTime(c.arrivalTime);
      _selectedDays.addAll(c.days);
      _transportMode = c.transportMode;
      _durationMinutes = c.durationMinutes;
      _selectedLat = c.latitude;
      _selectedLon = c.longitude;
    }
  }

  void _onSearchChanged(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await LocationService.searchPlaces(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _selectLocation(LocationResult location) async {
    _destController.text = location.name;
    _selectedLat = location.lat;
    _selectedLon = location.lon;
    setState(() => _searchResults = []);
    
    final duration = await RouteService.getTravelTime(
      startLat: 30.3165,
      startLon: 78.0322,
      endLat: location.lat,
      endLon: location.lon,
      mode: _transportMode
    );

    if (duration != null) {
      int safeDuration = duration;
      if (safeDuration < 0) safeDuration = 0;
      if (safeDuration > 120) safeDuration = 120; 

      setState(() => _durationMinutes = safeDuration);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Travel time updated: $safeDuration mins")),
      );
    }
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select at least one day")),
        );
        return;
      }
      
      final newCommute = Commute(
        id: widget.commuteToEdit?.id ?? DateTime.now().toString(),
        destination: _destController.text,
        arrivalTime: _formatTime(_arrivalTime),
        days: _selectedDays,
        durationMinutes: _durationMinutes,
        transportMode: _transportMode,
        latitude: _selectedLat,
        longitude: _selectedLon,
      );
      
      Navigator.pop(context, newCommute);
    }
  }

  TimeOfDay _parseTime(String s) {
    try {
      final parts = s.split(" ");
      final timeParts = parts[0].split(":");
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1] == "PM" && hour != 12) hour += 12;
      if (parts.length > 1 && parts[1] == "AM" && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTime(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    String hour = dt.hour > 12 ? (dt.hour - 12).toString() : (dt.hour == 0 ? "12" : dt.hour.toString());
    String minute = dt.minute.toString().padLeft(2, '0');
    String period = dt.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.commuteToEdit == null ? "Add Commute" : "Edit Commute")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Column(
                children: [
                  TextFormField(
                    controller: _destController,
                    decoration: const InputDecoration(
                      labelText: "Destination",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onSearchChanged,
                    validator: (val) => val!.isEmpty ? "Enter a destination" : null,
                  ),
                  if (_isSearching)
                    const LinearProgressIndicator(minHeight: 4),
                ],
              ),
              
              if (_searchResults.isNotEmpty)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, 
                    border: Border.all(color: Colors.grey.shade800),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) => ListTile(
                      title: Text(_searchResults[i].name),
                      subtitle: Text(_searchResults[i].address, style: const TextStyle(fontSize: 12)),
                      onTap: () => _selectLocation(_searchResults[i]),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  const Text("Transport: "),
                  DropdownButton<String>(
                    value: _transportMode,
                    dropdownColor: Theme.of(context).cardColor,
                    items: const [
                      DropdownMenuItem(value: 'driving', child: Text("Car")),
                      DropdownMenuItem(value: 'two_wheeler', child: Text("Motorcycle")),
                    ],
                    onChanged: (val) => setState(() => _transportMode = val!),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  const Text("Arrival Time: "),
                  TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _arrivalTime);
                      if (t != null) setState(() => _arrivalTime = t);
                    },
                    child: Text(_formatTime(_arrivalTime), style: const TextStyle(fontSize: 18, color: Colors.orange)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text("Days:"),
              Wrap(
                spacing: 8,
                children: _daysOfWeek.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day),
                    selected: isSelected,
                    selectedColor: Colors.orange, 
                    checkmarkColor: Colors.white,
                    onSelected: (selected) {
                      setState(() {
                        selected ? _selectedDays.add(day) : _selectedDays.remove(day);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              Text("Travel Duration: $_durationMinutes mins"),
              Slider(
                value: _durationMinutes.toDouble(),
                min: 0,
                max: 120,
                divisions: 120,
                activeColor: Colors.orange,
                label: "$_durationMinutes mins",
                onChanged: (val) => setState(() => _durationMinutes = val.round()),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Save Commute"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}