import 'package:attendance_manager/models/datetime_utility.dart';
import 'package:attendance_manager/models/timecard_data.dart';

import 'attend_data.dart';
import 'daily_timecard.dart';

class MonthlyTimecard {
  final String name;
  final DateTime date;

  late Map<int, DailyTimecard> dataMap;

  MonthlyTimecard(this.name, int year, int month)
      : date = DateTime(year, month) {
    int lastDay = date.lastDayOfMonth;
    dataMap = {};
    for (int i = 1; i <= lastDay; ++i) {
      dataMap[i] = DailyTimecard(name, year, month, i);
    }
  }

  static Map<int, MonthlyTimecard> create(
      String name, int year, int month, List<AttendData> attendDataList) {
    List<TimecardData> dataList = TimecardData.create(attendDataList);
    Map<int, MonthlyTimecard> monthlyDataMap = {};
    monthlyDataMap[month] = MonthlyTimecard(name, year, month);

    for (int i = 0; i < dataList.length; ++i) {
      TimecardData data = dataList[i];
      int year = data.date!.year;
      int month = data.date!.month;

      monthlyDataMap.putIfAbsent(
          month, () => MonthlyTimecard(name, year, month));

      int day = data.date!.day;

      monthlyDataMap[month]!.dataMap[day]!.dataList.add(data);
    }

    monthlyDataMap.forEach((month, monthlyTimecard) {
      monthlyTimecard.dataMap.forEach((day, dailyTimecard) {
        List<TimecardData> dataList = dailyTimecard.dataList;
        if (dataList.isEmpty) {
          dataList
              .add(TimecardData(dailyTimecard.name, date: dailyTimecard.date));
        }
      });
    });

    return monthlyDataMap;
  }

  List<List<String>> toCsvFormat() {
    //List<String> header = TimecardData.getElementName();
    List<List<String>> rows = [];

    dataMap.forEach((day, dailyTimecard) {
      List<TimecardData> dataList = dailyTimecard.dataList;

      for (int i = 0; i < dataList.length; ++i) {
        TimecardData data = dataList[i];
        rows.add(data.toCsvFormat());
      }
    });

    return rows;
  }
}
