import 'package:attendance_manager/models/datetime_utility.dart';
import 'package:attendance_manager/models/timecard_data.dart';
import 'package:intl/intl.dart';

import 'calendar.dart';

class DailyTimecard {
  final String name;
  final DateTime date;
  final List<CalendarEvent> _events;
  //final List<String> remarks = [];
  final DateFormat _monthDayFormat = DateFormat('MM/dd(E)', 'ja');
  late List<TimecardData> dataList;

  bool get isHoliday {
    if (!date.isWeekday) {
      return true;
    }

    if (_events.isNotEmpty) {
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

  String get eventsStr {
    String str = '';
    if (_events.isNotEmpty) {
      for (var event in _events) {
        str += '${event.name}, ';
      }
    }
    if (str.length >= 2) {
      str = str.substring(0, str.length - 2);
    }

    return str;
  }

  String get remarksStr {
    String str = '';
    if (_events.isNotEmpty) {
      for (var event in _events) {
        str += '${event.name}, ';
      }
    }

    var errs = errors;
    if (errs.isNotEmpty) {
      for (var error in errs) {
        str += '$error, ';
      }
    }

    var rmks = remarks;
    if (rmks.isNotEmpty) {
      for (var remark in rmks) {
        str += '$remark, ';
      }
    }

    if (str.length >= 2) {
      str = str.substring(0, str.length - 2);
    }

    return str;
  }

  List<String> get remarks {
    List<String> rmks = [];
    for (var data in dataList) {
      for (var remark in data.remarks) {
        if (!rmks.contains(remark)) {
          rmks.add(remark);
        }
      }
    }

    return rmks;
  }

  List<String> get errors {
    List<String> errs = [];
    for (var data in dataList) {
      for (var error in data.errors) {
        if (!errs.contains(error)) {
          errs.add(error);
        }
      }
    }

    return errs;
  }

  bool get hasError {
    return errors.isNotEmpty;
  }

  bool get hasMultipleData {
    return dataList.length > 1;
  }

  DailyTimecard(this.name, int year, int month, int day,
      {List<CalendarEvent>? events})
      : date = DateTime(year, month, day),
        _events = events ?? [] {
    dataList = [];
  }
}
