import 'package:attendance_manager/models/datetime_utility.dart';
import 'package:attendance_manager/models/timecard_data.dart';
import 'package:intl/intl.dart';

import 'calendar.dart';

class DailyTimecard {
  final String name;
  final DateTime date;
  final List<CalendarEvent> events = [];
  final DateFormat _monthDayFormat = DateFormat('MM/dd(E)', 'ja');

  bool get isHoliday {
    if (!date.isWeekday) {
      return true;
    }

    if (events.isNotEmpty) {
      return true;
    }

    return false;
  }

  String get clockInTimeStr {
    if (dataList.isEmpty) {
      return '';
    } else {
      return dataList.first.clockInTimeStr;
    }
  }

  String get clockOutTimeStr {
    if (dataList.isEmpty) {
      return '';
    } else {
      return dataList.last.clockOutTimeStr;
    }
  }

  String get elapsedTimeStr {
    double time = elapsedTime;

    return time != 0 ? time.toStringAsFixed(1) : '';
  }

  double get elapsedTime {
    double time = 0;
    for (var element in dataList) {
      time += element.elapsedTime;
    }

    return time;
  }

  String get monthDayStr {
    String dateStr = _monthDayFormat.format(date);
    return dateStr;
  }

  String get remarksStr {
    String str = '';
    if (events.isNotEmpty) {
      for (var event in events) {
        str += '${event.name}, ';
      }

      str = str.substring(0, str.length - 2);
    }

    return str;
  }

  late List<TimecardData> dataList;

  DailyTimecard(this.name, int year, int month, int day)
      : date = DateTime(year, month, day) {
    dataList = [];
  }
}
