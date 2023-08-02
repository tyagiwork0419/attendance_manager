import 'package:intl/intl.dart';

import 'date.dart';

class Calendar {
  late Map<Date, List<CalendarEvent>> eventMap;

  Calendar() {
    eventMap = {};
  }

  setEvents(List<CalendarEvent> events) {
    eventMap.clear();

    for (var event in events) {
      eventMap[event.date] != null
          ? eventMap[event.date]!.add(event)
          : eventMap[event.date] = [event];
    }
  }
}

class CalendarEvent {
  final String name;
  final Date date;

  static final DateFormat dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm:ss');
  CalendarEvent(this.name, this.date);

  CalendarEvent.fromJson(Map<String, dynamic> jsonMap)
      : name = jsonMap['name']!,
        date = Date.createFromDateTime(dateTimeFormat.parse(jsonMap['date']));
}
