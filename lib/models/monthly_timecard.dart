import 'package:attendance_manager/models/datetime_utility.dart';
import 'package:attendance_manager/models/timecard_data.dart';

import 'attend_data.dart';
import 'calendar.dart';
import 'daily_timecard.dart';
import 'date.dart';

class MonthlyTimecard {
  final String name;
  final DateTime date;

  late Map<int, DailyTimecard> dailyTimecards;
  //final Calendar calendar;

  MonthlyTimecard(this.name, int year, int month)
      : date = DateTime(year, month),
        dailyTimecards = {};

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

    MonthlyTimecard monthlyTimecard = MonthlyTimecard(name, year, month);
    initializeDailytimecard(monthlyTimecard);
    setHoliday(monthlyTimecard, calendar);

    for (int i = 0; i < dataList.length; ++i) {
      TimecardData data = dataList[i];
      int m = data.date!.month;

      if (m != month) {
        continue;
      }

      int d = data.date!.day;
      var dailyTimecard = monthlyTimecard.dailyTimecards[d];

      var list = dailyTimecard!.dataList;
      bool isHoliday = !data.date!.isWeekday || dailyTimecard.events.isNotEmpty;
      data.isHoliday = isHoliday;

      list.add(data);
    }

    return monthlyTimecard;
  }

  static void initializeDailytimecard(MonthlyTimecard monthlyTimecard) {
    int lastDay = monthlyTimecard.date.lastDayOfMonth;
    for (int i = 1; i <= lastDay; ++i) {
      monthlyTimecard.dailyTimecards[i] = DailyTimecard(monthlyTimecard.name,
          monthlyTimecard.date.year, monthlyTimecard.date.month, i);
    }
  }

  static void setHoliday(MonthlyTimecard monthlyTimecard, Calendar calendar) {
    int year = monthlyTimecard.date.year;
    int month = monthlyTimecard.date.month;

    monthlyTimecard.dailyTimecards.forEach((day, dailyTimecard) {
      Date date = Date(year, month, day);
      if (calendar.eventMap.containsKey(date)) {
        List<CalendarEvent> events = calendar.eventMap[date]!;
        dailyTimecard.events.addAll(events);
        //debugPrint('name = {events[0].name}');
      }
    });
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
        strs.add(dailyTimecard.remarksStr);
        rows.add(strs);
      }
    });

    return rows;
  }
}
