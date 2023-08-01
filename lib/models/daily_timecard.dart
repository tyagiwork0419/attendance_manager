import 'package:attendance_manager/models/timecard_data.dart';
import 'package:intl/intl.dart';

class DailyTimecard {
  final String name;
  final DateTime date;
  final DateFormat _monthDayFormat = DateFormat('MM/dd(E)', 'ja');
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
    double time = 0;

    for (var element in dataList) {
      time += element.elapsedTime;
    }

    return time != 0 ? time.toStringAsFixed(1) : '';
  }

  String get monthDayStr {
    String dateStr = _monthDayFormat.format(date);
    return dateStr;
  }

  late List<TimecardData> dataList;

  DailyTimecard(this.name, int year, int month, int day)
      : date = DateTime(year, month, day) {
    dataList = [];
  }
}
