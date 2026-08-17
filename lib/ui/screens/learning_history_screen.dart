import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/commute_model.dart';
import '../../services/commute_history_service.dart';
import '../styles.dart';

// ---------------------------------------------------------------------------
// DEBUG: Learning History Viewer
// Read-only display of the existing CommuteHistoryService data.
// ---------------------------------------------------------------------------

class LearningHistoryScreen extends StatefulWidget {
  const LearningHistoryScreen({super.key});

  @override
  State<LearningHistoryScreen> createState() => _LearningHistoryScreenState();
}

class _LearningHistoryScreenState extends State<LearningHistoryScreen> {
  bool _loading = true;
  List<_CommuteHistoryGroup> _groups = [];
  int _globalBuffer = 0;
  int _globalEntryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // ── Load commutes from SharedPreferences (same key the app uses) ─────────
    List<Commute> commutes = [];
    try {
      final raw = prefs.getString('commutes');
      if (raw != null) {
        commutes = (json.decode(raw) as List)
            .map((e) => Commute.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('[LEARN_DEBUG] Failed to load commutes: $e');
    }

    // ── Global tier ─────────────────────────────────────────────────────────
    final globalHistory = await CommuteHistoryService.getGlobalHistory();
    final int globalBuffer = prefs.getInt('reach_global_buffer') ?? 0;

    // ── Per-commute tier ────────────────────────────────────────────────────
    final List<_CommuteHistoryGroup> groups = [];

    for (final commute in commutes) {
      final history = await CommuteHistoryService.getCommuteHistory(commute.id);
      final int commuteBuffer =
          prefs.getInt('reach_cbuffer_${commute.id}') ?? 0;

      // Build entries list, newest first.
      final entries = history.reversed.map((e) {
        return _HistoryEntry(
          outcome: e['outcome'] as String? ?? 'unknown',
          delayMinutes: (e['delayMinutes'] as num?)?.toInt() ?? 0,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            (e['ts'] as num?)?.toInt() ?? 0,
          ),
        );
      }).toList();

      groups.add(_CommuteHistoryGroup(
        commuteName: commute.customTitle ?? commute.title,
        commuteBuffer: commuteBuffer,
        entries: entries,
      ));
    }

    setState(() {
      _groups = groups;
      _globalBuffer = globalBuffer;
      _globalEntryCount = globalHistory.length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasAnyHistory = _groups.any((g) => g.entries.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Learning History'),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.amber.withOpacity(0.5), width: 1),
              ),
              child: const Text(
                'DEBUG',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                // ── Global summary ─────────────────────────────────────────
                _buildGlobalSummary(isDark),
                const SizedBox(height: 16),

                if (!hasAnyHistory)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'No learning history available.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                else
                  ..._groups
                      .where((g) => g.entries.isNotEmpty)
                      .map((g) => _buildCommuteGroup(g, isDark)),
              ],
            ),
    );
  }

  Widget _buildGlobalSummary(bool isDark) {
    final cardColor =
        isDark ? Theme.of(context).cardColor : ReachStyles.lightCard;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ReachStyles.primaryOrange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: ReachStyles.primaryOrange),
              const SizedBox(width: 8),
              Text(
                'Global Learning',
                style: TextStyle(
                  color: ReachStyles.primaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            label: 'Global adaptive buffer',
            value: '$_globalBuffer min',
            note: _globalBuffer == 0
                ? 'Needs ≥3 data points'
                : 'Added to every commute',
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          _buildInfoRow(
            label: 'Global history entries',
            value: '$_globalEntryCount / 7 (rolling window)',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCommuteGroup(_CommuteHistoryGroup group, bool isDark) {
    final cardColor =
        isDark ? Theme.of(context).cardColor : ReachStyles.lightCard;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Commute header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      group.commuteName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ReachStyles.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${group.commuteBuffer} min buffer',
                      style: TextStyle(
                        color: ReachStyles.primaryOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 20, indent: 16, endIndent: 16),
            // History entries (newest first)
            ...group.entries.map((e) => _buildEntryRow(e, isDark)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryRow(_HistoryEntry entry, bool isDark) {
    final dateStr = _formatDate(entry.timestamp);
    final timeStr = _formatTime(entry.timestamp);

    Color outcomeColor;
    IconData outcomeIcon;
    String outcomeLabel;
    switch (entry.outcome) {
      case 'reached':
        outcomeColor = Colors.green;
        outcomeIcon = Icons.check_circle_outline;
        outcomeLabel = 'Reached';
        break;
      case 'almost':
        outcomeColor = Colors.orange;
        outcomeIcon = Icons.access_time_outlined;
        outcomeLabel = 'Almost';
        break;
      default:
        outcomeColor = Colors.grey;
        outcomeIcon = Icons.help_outline;
        outcomeLabel = 'Unknown';
    }

    final delayText = entry.delayMinutes >= 0
        ? '+${entry.delayMinutes} min late'
        : '${entry.delayMinutes.abs()} min early';
    final delayColor = entry.delayMinutes > 0
        ? Colors.redAccent
        : entry.delayMinutes < 0
            ? Colors.green
            : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(outcomeIcon, size: 16, color: outcomeColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateStr at $timeStr',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Text(
                  outcomeLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: outcomeColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            delayText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: delayColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    String? note,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final hh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final ampm = h >= 12 ? 'PM' : 'AM';
    return '$hh:$m $ampm';
  }
}

// ---------------------------------------------------------------------------
// Data models (internal)
// ---------------------------------------------------------------------------

class _CommuteHistoryGroup {
  final String commuteName;
  final int commuteBuffer;
  final List<_HistoryEntry> entries;

  const _CommuteHistoryGroup({
    required this.commuteName,
    required this.commuteBuffer,
    required this.entries,
  });
}

class _HistoryEntry {
  final String outcome;
  final int delayMinutes;
  final DateTime timestamp;

  const _HistoryEntry({
    required this.outcome,
    required this.delayMinutes,
    required this.timestamp,
  });
}
