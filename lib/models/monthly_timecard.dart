import 'package:attendance_manager/models/datetime_utility.dart';
import 'package:attendance_manager/models/timecard_data.dart';

import 'attend_data.dart';
import 'calendar.dart';
import 'daily_timecard.dart';
import 'date.dart';

class MonthlyTimecard {
  final String name;
  final DateTime date;

  late Map<int, DailyTimecard> dataMap;
  final Calendar calendar;

  MonthlyTimecard(this.name, int year, int month, this.calendar)
      : date = DateTime(year, month) {
    int lastDay = date.lastDayOfMonth;
    dataMap = {};
    for (int i = 1; i <= lastDay; ++i) {
      dataMap[i] = DailyTimecard(name, year, month, i);
    }

    dataMap.forEach((day, dailyTimecard) {
      Date date = Date(year, month, day);
      if (calendar.eventMap.containsKey(date)) {
        List<CalendarEvent> events = calendar.eventMap[date]!;
        dailyTimecard.events.addAll(events);
        //debugPrint('name = {events[0].name}');
      }
    });
  }

  double get sumOfElapsedTime {
    double sum = 0;
    dataMap.forEach((day, dailyTimecard) {
      sum += dailyTimecard.elapsedTime;
    });

    return sum;
  }

  String get sumOfElapsedTimeStr {
    double time = sumOfElapsedTime;
    return time != 0 ? time.toStringAsFixed(1) : '';
  }

  static Map<int, MonthlyTimecard> create(String name, int year, int month,
      List<AttendData> attendDataList, Calendar calendar) {
    List<TimecardData> dataList = TimecardData.create(attendDataList);
    Map<int, MonthlyTimecard> monthlyDataMap = {};
    monthlyDataMap[month] = MonthlyTimecard(name, year, month, calendar);

    for (int i = 0; i < dataList.length; ++i) {
      TimecardData data = dataList[i];
      int year = data.date!.year;
      int month = data.date!.month;

      monthlyDataMap.putIfAbsent(
          month, () => MonthlyTimecard(name, year, month, calendar));

      int day = data.date!.day;
      var dailyTimecard = monthlyDataMap[month]!.dataMap[day];

      var list = dailyTimecard!.dataList;
      bool isHoliday = !data.date!.isWeekday || dailyTimecard.events.isNotEmpty;
      data.isHoliday = isHoliday;

      list.add(data);
    }
    return monthlyDataMap;
  }

  List<List<String>> toCsvFormat() {
    List<List<String>> rows = [];

    dataMap.forEach((day, dailyTimecard) {
      List<TimecardData>? dataList = dailyTimecard.dataList;

      if (dataList.isEmpty) {
        rows.add(
            [dailyTimecard.monthDayStr, '', '', '', dailyTimecard.remarksStr]);
        return;
      }

      for (int i = 0; i < dataList.length; ++i) {
        TimecardData data = dataList[i];
        List<String> strs = data.toCsvFormat();
        strs.add(dailyTimecard.remarksStr);
        rows.add(strs);
      }
    });

    return rows;
  }
}
