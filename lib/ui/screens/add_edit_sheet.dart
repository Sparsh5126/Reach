import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:uuid/uuid.dart';
import '../../models/commute_model.dart';
import '../../services/location_service.dart';
import '../styles.dart';

class AddEditSheet extends StatefulWidget {
  final Function(Commute) onSave;
  final Commute? existingCommute;
  final bool isSheet;

  const AddEditSheet({super.key, required this.onSave, this.existingCommute, this.isSheet = false});

  @override
  State<AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends State<AddEditSheet> {
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
    _initializeData();
  }

  void _initializeData() {
    // 1. Restore Mode
    if (widget.existingCommute != null) {
      final m = widget.existingCommute!.mode;
      if (m == 'motorcycle') _selectedMode = 1;
      else if (m == 'train') _selectedMode = 2;
      else if (m == 'flight') _selectedMode = 3;
      else _selectedMode = 0;
    }

    String initialTitle = widget.existingCommute?.title ?? "";
    String? initialELoc = widget.existingCommute?.eLoc;
    double? initialLat = widget.existingCommute?.lat;
    double? initialLon = widget.existingCommute?.lon;

    if (initialELoc == null && initialTitle.contains(',')) {
      List<String> parts = initialTitle.split(',').map((s) => s.trim()).toList();
      if (parts.isNotEmpty && parts.last.toLowerCase() == 'india') parts.removeLast();
      if (parts.isNotEmpty && RegExp(r'^\d+$').hasMatch(parts.last)) parts.removeLast();
      if (parts.length >= 3) initialTitle = "${parts.first}, ${parts[parts.length - 2]}";
      else if (parts.isNotEmpty) initialTitle = parts.first;
    }

    _titleController = TextEditingController(text: widget.existingCommute?.customTitle ?? "");
    _destinationController = TextEditingController(text: initialTitle);
    _selectedTime = _parseTime(widget.existingCommute?.time) ?? const TimeOfDay(hour: 8, minute: 30);
    _selectedDays = List.from(widget.existingCommute?.days ?? []);
    _lat = initialLat;
    _lon = initialLon;
    _eLoc = initialELoc;
    _isFavorite = widget.existingCommute?.isFavorite ?? false;
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
      if (mounted) setState(() { _suggestions = results; _isSearching = false; });
    });
  }

  void _selectLocation(LocationResult place) {
    HapticFeedback.selectionClick();
    setState(() {
      _destinationController.text = place.name;
      _eLoc = place.eLoc; _lat = place.lat; _lon = place.lon;
      _suggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _submitData() {
    if (_destinationController.text.isEmpty) return;
    if (_selectedDays.isEmpty) {
      showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text("Select a Day", style: TextStyle(color: Colors.white)),
          content: const Text("Please select at least one day for your commute.", style: TextStyle(color: Colors.grey)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("OK", style: TextStyle(color: ReachStyles.primaryOrange)))],
        )
      );
      return;
    }
    
    HapticFeedback.mediumImpact();

    String modeStr = 'car';
    if (_selectedMode == 1) modeStr = 'motorcycle';
    else if (_selectedMode == 2) modeStr = 'train';
    else if (_selectedMode == 3) modeStr = 'flight';

    widget.onSave(Commute(
      id: widget.existingCommute?.id ?? const Uuid().v4(),
      title: _destinationController.text,
      customTitle: _titleController.text.isEmpty ? null : _titleController.text,
      time: _selectedTime.format(context),
      mode: modeStr,
      days: _selectedDays,
      lat: _lat ?? 0.0, lon: _lon ?? 0.0, eLoc: _eLoc,
      isFavorite: _isFavorite,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? ReachStyles.darkText : ReachStyles.lightText;
    final inputColor = isDark ? Colors.grey[900] : Colors.grey[200];

    Widget content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(textColor),
          const SizedBox(height: 20),
          _buildTitleInput(textColor, inputColor!),
          const SizedBox(height: 16),
          _buildModeSelector(),
          const SizedBox(height: 16),
          
          if (_selectedMode >= 2) ...[
            _buildPickupToggle(textColor, inputColor),
            const SizedBox(height: 16),
          ],

          _buildDestinationInput(textColor, inputColor),
          _buildSuggestionsList(textColor, isDark),
          const SizedBox(height: 24),
          _buildDaySelector(inputColor),
          const SizedBox(height: 24),
          _buildActionButtons(textColor, inputColor),
          const SizedBox(height: 20),
        ],
      ),
    );

    if (widget.isSheet) {
      final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
      return Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: content,
      );
    } else {
      return Scaffold(body: SafeArea(child: Padding(padding: ReachStyles.pagePadding, child: content)));
    }
  }

  Widget _buildHeader(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.existingCommute == null ? "New Trip" : "Edit Trip",
            style: ReachStyles.heading.copyWith(fontSize: 28, color: color)),
        IconButton(
          icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, 
                      color: _isFavorite ? ReachStyles.accentRed : Colors.grey),
          onPressed: () {
             HapticFeedback.selectionClick();
             setState(() => _isFavorite = !_isFavorite);
          },
        ),
      ],
    );
  }

  Widget _buildTitleInput(Color textColor, Color inputColor) {
    return TextField(
      controller: _titleController,
      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: "Trip Name (e.g. Work)",
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true, fillColor: inputColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(child: _ModeTile(label: "Car", icon: Icons.directions_car, isSelected: _selectedMode == 0, onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedMode = 0); })), // <--- ADDED HAPTIC
        const SizedBox(width: 8),
        Expanded(child: _ModeTile(label: "Bike", icon: Icons.two_wheeler, isSelected: _selectedMode == 1, onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedMode = 1); })), // <--- ADDED HAPTIC
        const SizedBox(width: 8),
        Expanded(child: _ModeTile(label: "Train", icon: Icons.train, isSelected: _selectedMode == 2, onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedMode = 2); })), // <--- ADDED HAPTIC
        const SizedBox(width: 8),
        Expanded(child: _ModeTile(label: "Flight", icon: Icons.flight, isSelected: _selectedMode == 3, onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedMode = 3); })), // <--- ADDED HAPTIC
      ],
    );
  }

  Widget _buildPickupToggle(Color textColor, Color inputColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(_isPickup ? Icons.person_pin_circle : Icons.flight_takeoff, color: ReachStyles.primaryOrange, size: 20),
              const SizedBox(width: 12),
              Text(_isPickup ? "Picking someone up" : "Catching the trip", style: TextStyle(color: textColor, fontSize: 14)),
            ],
          ),
          Switch(
            value: _isPickup,
            onChanged: (val) {
               HapticFeedback.lightImpact();
               setState(() => _isPickup = val);
            },
            activeColor: ReachStyles.primaryOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationInput(Color textColor, Color inputColor) {
      return TextField(
            controller: _destinationController,
            onChanged: _onSearchChanged,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: "Search Destination",
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true, fillColor: inputColor,
              prefixIcon: Icon(Icons.search, color: ReachStyles.primaryOrange),
              suffixIcon: _isSearching ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          );
  }

  Widget _buildSuggestionsList(Color textColor, bool isDark) {
    if (_suggestions.isEmpty) return const SizedBox.shrink();
    return Container(
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
            subtitle: Text(p.address, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () => _selectLocation(p),
          );
        },
      ),
    );
  }

  Widget _buildDaySelector(Color inputColor) {
     return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        bool isSelected = _selectedDays.contains(_fullDays[index]);
        return GestureDetector(
          onTap: () {
             HapticFeedback.selectionClick();
             setState(() => isSelected ? _selectedDays.remove(_fullDays[index]) : _selectedDays.add(_fullDays[index]));
          },
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isSelected ? ReachStyles.primaryOrange : inputColor, 
              shape: BoxShape.circle
            ),
            alignment: Alignment.center,
            child: Text(_weekDays[index], style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
          ),
        );
      }),
    );
  }

  Widget _buildActionButtons(Color textColor, Color inputColor) {
     return Row(
      children: [
        Expanded(
          flex: 1, 
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final picked = await showTimePicker(context: context, initialTime: _selectedTime);
              if (picked != null) setState(() => _selectedTime = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time_filled, color: ReachStyles.primaryOrange),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: ReachStyles.primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
              ),
              child: const Text("Save", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
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

class _ModeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTile({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isSelected ? ReachStyles.primaryOrange : (isDark ? Colors.grey[900] : Colors.grey[200]);
    final fg = isSelected ? Colors.white : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Icon(icon, color: fg, size: 22), Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold))]),
      ),
    );
  }
}