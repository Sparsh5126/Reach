import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'commute_model.dart';
import 'location_service.dart';

class AddCommutePage extends StatefulWidget {
  final Function(Commute) onSave;
  final Commute? existingCommute;
  final bool isSheet;

  const AddCommutePage({
    super.key, 
    required this.onSave, 
    this.existingCommute,
    this.isSheet = false,
  });

  @override
  State<AddCommutePage> createState() => _AddCommutePageState();
}

class _AddCommutePageState extends State<AddCommutePage> {
  late TextEditingController _titleController;
  late TextEditingController _destinationController;
  late TimeOfDay _selectedTime;
  int _selectedMode = 0;
  bool _isPickup = false;
  List<String> _selectedDays = [];
  bool _isFavorite = false;
  
  List<LocationResult> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounce;
  
  double? _lat;
  double? _lon;
  String? _eLoc;

  final List<String> _weekDays = ["M", "T", "W", "T", "F", "S", "S"];
  final List<String> _fullDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  @override
  void initState() {
    super.initState();
    
    // 1. RESTORE EXISTING MODE (Fix for the bug)
    if (widget.existingCommute != null) {
      final m = widget.existingCommute!.mode;
      if (m == 'motorcycle') _selectedMode = 1;
      else if (m == 'train') _selectedMode = 2;
      else if (m == 'flight') _selectedMode = 3;
      else _selectedMode = 0; // Default to car
    }

    // Address Cleanup Logic
    String initialTitle = widget.existingCommute?.title ?? "";
    String? initialELoc = widget.existingCommute?.eLoc;
    double? initialLat = widget.existingCommute?.lat;
    double? initialLon = widget.existingCommute?.lon;

    if (initialELoc == null && initialTitle.contains(',')) {
      List<String> parts = initialTitle.split(',').map((s) => s.trim()).toList();
      if (parts.isNotEmpty && parts.last.toLowerCase() == 'india') parts.removeLast();
      if (parts.isNotEmpty && RegExp(r'^\d+$').hasMatch(parts.last)) parts.removeLast();

      if (parts.length >= 3) {
        String placeName = parts.first;
        String cityName = parts[parts.length - 2]; 
        initialTitle = "$placeName, $cityName";
      } else if (parts.length == 2) {
        initialTitle = "${parts.first}, ${parts.last}";
      } else if (parts.isNotEmpty) {
        initialTitle = parts.first;
      }
    }

    _titleController = TextEditingController(text: widget.existingCommute?.customTitle ?? "");
    _destinationController = TextEditingController(text: initialTitle);
    _selectedTime = _parseTime(widget.existingCommute?.time) ?? const TimeOfDay(hour: 8, minute: 30);
    _selectedDays = List.from(widget.existingCommute?.days ?? []);
    _lat = initialLat;
    _lon = initialLon;
    _eLoc = initialELoc;
    _isFavorite = widget.existingCommute?.isFavorite ?? false;

    if (_destinationController.text.isNotEmpty && _eLoc == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _onSearchChanged(_destinationController.text);
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _isSearching = true);
      final results = await LocationService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectLocation(LocationResult place) {
    setState(() {
      _destinationController.text = place.name;
      _eLoc = place.eLoc; 
      _lat = place.lat;
      _lon = place.lon;
      _suggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _submitData() {
    if (_destinationController.text.isEmpty) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one day"), backgroundColor: Colors.red));
      return;
    }

    if (_eLoc == null) {
      if (_suggestions.isNotEmpty) {
        final bestMatch = _suggestions.first;
        _eLoc = bestMatch.eLoc;
        _lat = bestMatch.lat;
        _lon = bestMatch.lon;
        _destinationController.text = bestMatch.name;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a valid location."), backgroundColor: Colors.orange));
        return;
      }
    }
    
    String modeStr = 'car';
    if (_selectedMode == 1) modeStr = 'motorcycle';
    else if (_selectedMode == 2) modeStr = 'train';
    else if (_selectedMode == 3) modeStr = 'flight';

    final String finalId = widget.existingCommute?.id ?? const Uuid().v4();

    widget.onSave(Commute(
      id: finalId, 
      title: _destinationController.text, 
      customTitle: _titleController.text.isEmpty ? null : _titleController.text,
      time: _selectedTime.format(context),
      mode: modeStr,
      days: _selectedDays,
      lat: _lat ?? 0.0, 
      lon: _lon ?? 0.0,
      eLoc: _eLoc,
      isFavorite: _isFavorite,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final inputColor = isDark ? Colors.grey[900] : Colors.grey[200];
    final hintColor = isDark ? Colors.grey : Colors.grey[600];

    Widget content = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.existingCommute == null ? "New Trip" : "Edit Trip",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
              IconButton(
                icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.red : hintColor),
                onPressed: () => setState(() => _isFavorite = !_isFavorite),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // TITLE
          TextField(
            controller: _titleController,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: "Trip Name (e.g. Work, Gym)",
              hintStyle: TextStyle(color: hintColor),
              filled: true, fillColor: inputColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          
          // MODES
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
          const SizedBox(height: 16),
          if (_selectedMode >= 2) Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildPickupToggle(isDark, inputColor!, textColor)),

          // DESTINATION
          TextField(
            controller: _destinationController,
            onChanged: _onSearchChanged,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: "Search Destination",
              hintStyle: TextStyle(color: hintColor),
              filled: true, fillColor: inputColor,
              prefixIcon: const Icon(Icons.search, color: Colors.orange),
              suffixIcon: _isSearching ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),

          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(color: isDark ? Colors.grey[850] : Colors.white, borderRadius: BorderRadius.circular(12)),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (ctx, i) {
                  final p = _suggestions[i];
                  return ListTile(
                    title: Text(p.name, style: TextStyle(color: textColor)),
                    subtitle: Text(p.address, style: TextStyle(color: hintColor, fontSize: 12)),
                    onTap: () => _selectLocation(p),
                  );
                },
              ),
            ),

          const SizedBox(height: 24),
          
          // DAYS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              bool isSelected = _selectedDays.contains(_fullDays[index]);
              return GestureDetector(
                onTap: () => setState(() => isSelected ? _selectedDays.remove(_fullDays[index]) : _selectedDays.add(_fullDays[index])),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: isSelected ? Colors.orange[800] : inputColor, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(_weekDays[index], style: TextStyle(color: isSelected ? Colors.white : hintColor)),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // TIME & SAVE
          Row(
            children: [
              Expanded(
                flex: 1, 
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                    if (picked != null) setState(() => _selectedTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_filled, color: Colors.orange),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _selectedTime.format(context), 
                            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1, 
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submitData,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text("Save", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );

    if (widget.isSheet) {
      final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
      return Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: content,
      );
    } else {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
            child: content,
          ),
        ),
      );
    }
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
              Text(_isPickup ? "Picking someone up" : "Catching the trip", style: TextStyle(color: textColor, fontSize: 14)),
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

  TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    try {
      final format = RegExp(r'(\d+):(\d+)\s+(AM|PM)');
      final match = format.firstMatch(s);
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
}

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
            Text(label, style: TextStyle(color: isSelected ? Colors.white : unselectedIconColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}