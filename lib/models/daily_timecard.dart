import 'package:attendance_manager/models/datetime_utility.dart';
import 'package:attendance_manager/models/timecard_data.dart';
import 'package:intl/intl.dart';

import 'calendar.dart';

class DailyTimecard {
  final String name;
  final DateTime date;
  final List<CalendarEvent> events = [];
  //final List<String> remarks = [];
  final DateFormat _monthDayFormat = DateFormat('MM/dd(E)', 'ja');
  late List<TimecardData> dataList;

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
    }

    var errs = errors;
    if (errs.isNotEmpty) {
      for (var error in errs) {
        str += '$error, ';
      }
    }

    if (hasPaidHoliday) {
      str += '有休, ';
    }

    if (str.length >= 2) {
      str = str.substring(0, str.length - 2);
    }

    return str;
  }

  bool get hasPaidHoliday {
    //List<String> remarks = [];
    for (var data in dataList) {
      //for (var remark in data.remarks) {
      if (data.remarks.isNotEmpty) {
        return true;
        /*
        if (!remarks.contains(remark)) {
          remarks.add(remark);
        }
        */
      }
    }

    return false;
  }

/*
  List<String> get remarks {
    String str = '';
    for (var data in dataList) {
      if (data.remarks.isNotEmpty) {
        str += data.remarksStr;
      }
    }
  }
  */

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

  DailyTimecard(this.name, int year, int month, int day)
      : date = DateTime(year, month, day) {
    dataList = [];
  }
}
