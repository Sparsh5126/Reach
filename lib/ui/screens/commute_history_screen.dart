import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/commute_model.dart';
import '../../services/commute_history_service.dart';
import '../styles.dart';

class CommuteHistoryScreen extends StatefulWidget {
  const CommuteHistoryScreen({super.key});

  @override
  State<CommuteHistoryScreen> createState() => _CommuteHistoryScreenState();
}

class _CommuteHistoryScreenState extends State<CommuteHistoryScreen> {
  bool _loading = true;
  List<_CommuteHistoryGroup> _groups = [];
  int _globalEntryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();

    List<Commute> commutes = [];
    try {
      final raw = prefs.getString('commutes');
      if (raw != null) {
        commutes = (json.decode(raw) as List)
            .map((e) => Commute.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('[HISTORY] Failed to load commutes: $e');
    }

    final List<_CommuteHistoryGroup> groups = [];

    for (final commute in commutes) {
      final history = await CommuteHistoryService.getTravelHistory(commute.id, commute.mode);

      final entries = history.reversed.map((e) {
        return _HistoryEntry(
          actualMinutes: (e['actualMinutes'] as num?)?.toInt() ?? 0,
          mapplsMinutes: (e['mapplsMinutes'] as num?)?.toInt() ?? 0,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            (e['ts'] as num?)?.toInt() ?? 0,
          ),
        );
      }).toList();

      groups.add(_CommuteHistoryGroup(
        commuteName: commute.customTitle ?? commute.title,
        mode: commute.mode,
        entries: entries,
      ));
    }

    if (!mounted) return;
    setState(() {
      _groups = groups;
      _globalEntryCount = groups.fold(0, (sum, g) => sum + g.entries.length);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final withHistory = _groups.where((g) => g.entries.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commute History', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ReachStyles.primaryOrange))
          : withHistory.isEmpty
              ? _buildEmpty(isDark)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    _buildSummary(isDark, withHistory),
                    const SizedBox(height: 20),
                    ...withHistory.map((g) => _buildCommuteGroup(g, isDark)),
                  ],
                ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ReachStyles.primaryOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_edu_rounded, size: 40, color: ReachStyles.primaryOrange),
            ),
            const SizedBox(height: 20),
            Text(
              'No trips recorded yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? ReachStyles.darkText : ReachStyles.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Reached" on the check-in notification after a trip and Reach will learn how long it really takes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[isDark ? 400 : 600], fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(bool isDark, List<_CommuteHistoryGroup> groups) {
    final cardColor = isDark ? Theme.of(context).cardColor : ReachStyles.lightCard;
    final all = groups.expand((g) => g.entries).toList();
    final avgDiff = all.isEmpty
        ? 0
        : (all.fold<int>(0, (s, e) => s + (e.actualMinutes - e.mapplsMinutes)) / all.length).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: ReachStyles.cardRadius,
        border: Border.all(color: ReachStyles.primaryOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _stat(
              '$_globalEntryCount',
              _globalEntryCount == 1 ? 'trip recorded' : 'trips recorded',
              isDark,
            ),
          ),
          Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.grey[300]),
          Expanded(
            child: _stat(
              '${avgDiff > 0 ? '+' : ''}$avgDiff min',
              'avg vs. estimate',
              isDark,
              valueColor: avgDiff > 0 ? ReachStyles.accentRed : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, bool isDark, {Color? valueColor}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: valueColor ?? ReachStyles.primaryOrange,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[isDark ? 400 : 600])),
      ],
    );
  }

  IconData _modeIcon(String mode) {
    final m = mode.toLowerCase();
    if (m.contains('motor') || m.contains('bike')) return Icons.two_wheeler;
    if (m.contains('train')) return Icons.train;
    if (m.contains('flight')) return Icons.flight;
    return Icons.directions_car;
  }

  Widget _buildCommuteGroup(_CommuteHistoryGroup group, bool isDark) {
    final cardColor = isDark ? Theme.of(context).cardColor : ReachStyles.lightCard;
    final txt = isDark ? ReachStyles.darkText : ReachStyles.lightText;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: ReachStyles.cardRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Icon(_modeIcon(group.mode), color: ReachStyles.primaryOrange, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.commuteName,
                    style: ReachStyles.cardTitle.copyWith(color: txt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${group.entries.length} ${group.entries.length == 1 ? 'trip' : 'trips'}',
                  style: TextStyle(color: Colors.grey[isDark ? 400 : 600], fontSize: 12),
                ),
              ],
            ),
          ),
          Divider(height: 1, indent: 20, endIndent: 20, color: isDark ? Colors.white10 : Colors.grey[200]),
          ...group.entries.map((e) => _buildEntryRow(e, isDark, txt)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildEntryRow(_HistoryEntry entry, bool isDark, Color txt) {
    final int diff = entry.actualMinutes - entry.mapplsMinutes;
    final String sign = diff > 0 ? '+' : '';
    final Color diffColor = diff > 0 ? ReachStyles.accentRed : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.actualMinutes} min',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: txt),
                ),
                const SizedBox(height: 2),
                Text(
                  'Estimated ${entry.mapplsMinutes} min • ${_formatDateTime(entry.timestamp)}',
                  style: TextStyle(color: Colors.grey[isDark ? 400 : 600], fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: diffColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$sign$diff min',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: diffColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day}/${dt.month} $h:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}

class _CommuteHistoryGroup {
  final String commuteName;
  final String mode;
  final List<_HistoryEntry> entries;

  _CommuteHistoryGroup({
    required this.commuteName,
    required this.mode,
    required this.entries,
  });
}

class _HistoryEntry {
  final int actualMinutes;
  final int mapplsMinutes;
  final DateTime timestamp;

  _HistoryEntry({
    required this.actualMinutes,
    required this.mapplsMinutes,
    required this.timestamp,
  });
}
