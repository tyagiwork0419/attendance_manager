import 'package:attendance_manager/models/datetime_utility.dart';
import 'package:attendance_manager/models/timecard_data.dart';

import 'attend_data.dart';
import 'calendar.dart';
import 'daily_timecard.dart';
import 'date.dart';

class MonthlyTimecard {
  final String name;
  final DateTime date;

  final Map<int, DailyTimecard> dailyTimecards = {};
  //final Calendar calendar;

  MonthlyTimecard(this.name, int year, int month, Calendar calendar)
      : date = DateTime(year, month) {
    int lastDay = date.lastDayOfMonth;
    for (int i = 1; i <= lastDay; ++i) {
      List<CalendarEvent> events = [];
      Date d = Date(year, month, i);
      if (calendar.eventMap.containsKey(d)) {
        List<CalendarEvent> evts = calendar.eventMap[d]!;
        events.addAll(evts);
      }

      dailyTimecards[i] = DailyTimecard(name, year, month, i, events: events);
    }
  }

  double get sumOfElapsedTime {
    double sum = 0;
    dailyTimecards.forEach((day, dailyTimecard) {
      sum += dailyTimecard.elapsedTime;
    });

    return sum;
  }

  String get sumOfElapsedTimeStr {
    double time = sumOfElapsedTime;
    return time != 0 ? time.toStringAsFixed(1) : '';
  }

  static MonthlyTimecard create(String name, int year, int month,
      List<AttendData> attendDataList, Calendar calendar) {
    List<TimecardData> dataList = TimecardData.create(attendDataList);

    MonthlyTimecard monthlyTimecard =
        MonthlyTimecard(name, year, month, calendar);

    for (int i = 0; i < dataList.length; ++i) {
      TimecardData data = dataList[i];
      int m = data.date!.month;

      if (m != month) {
        continue;
      }

      int d = data.date!.day;
      var dailyTimecard = monthlyTimecard.dailyTimecards[d];

      var list = dailyTimecard!.dataList;

      list.add(data);
    }

    return monthlyTimecard;
  }

  List<List<String>> toCsvFormat() {
    List<List<String>> rows = [];

    dailyTimecards.forEach((day, dailyTimecard) {
      List<TimecardData>? dataList = dailyTimecard.dataList;

      if (dataList.isEmpty) {
        rows.add(
            [dailyTimecard.monthDayStr, '', '', '', dailyTimecard.remarksStr]);
        return;
      }

      for (int i = 0; i < dataList.length; ++i) {
        TimecardData data = dataList[i];
        List<String> strs = data.toCsvFormat();
        //strs.add(dailyTimecard.remarksStr);
        strs.add(dailyTimecard.eventsStr);
        rows.add(strs);
      }
    });

    return rows;
  }
}
