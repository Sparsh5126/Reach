import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class CalendarEventResult {
  final String title;
  final String location;
  final DateTime startTime;
  final String eventId;

  CalendarEventResult({
    required this.title,
    required this.location,
    required this.startTime,
    required this.eventId,
  });
}

class CalendarService {
  static final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
  }

  static Future<List<CalendarEventResult>> getUpcomingTravelEvents() async {
    var permissions = await _deviceCalendarPlugin.requestPermissions();
    if (!permissions.isSuccess || !permissions.data!) {
      debugPrint("CALENDAR: No permissions granted.");
      return [];
    }

    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (calendarsResult.data == null) {
      debugPrint("CALENDAR: No calendars found.");
      return [];
    }

    List<CalendarEventResult> relevantEvents = [];
    final now = DateTime.now();
    final rangeEnd = now.add(const Duration(days: 3)); 

    debugPrint("CALENDAR: Checking events from $now to $rangeEnd");

    for (var calendar in calendarsResult.data!) {
      if (calendar.isReadOnly == true) continue;

      final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
        calendar.id,
        RetrieveEventsParams(startDate: now, endDate: rangeEnd),
      );

      if (eventsResult.data != null) {
        for (var event in eventsResult.data!) {
          // Log every event found for debugging
          debugPrint("CALENDAR: Found '${event.title}' at '${event.location}'");

          if (event.location != null && event.location!.isNotEmpty && event.allDay == false) {
            relevantEvents.add(CalendarEventResult(
              title: event.title ?? "Untitled Event",
              location: event.location!,
              startTime: event.start ?? now,
              eventId: event.eventId ?? "",
            ));
          }
        }
      }
    }
    
    debugPrint("CALENDAR: Total valid travel events found: ${relevantEvents.length}");
    return relevantEvents;
  }
}