//import 'package:intl/intl.dart';
import 'package:intl/intl.dart';

import 'attend_data.dart';
import 'datetime_utility.dart';

class TimecardData {
  late String name;
  late DateTime? date;

  late DateTime? clockInTime;
  late DateTime? clockOutTime;

  final DateFormat _monthDayFormat = DateFormat('MM/dd(E)', 'ja');

  TimecardData(this.name, {this.date, this.clockInTime, this.clockOutTime}) {
    if (date != null) {
      return;
    }

    if (clockInTime != null) {
      date = DateTime(clockInTime!.year, clockInTime!.month, clockInTime!.day);
    } else if (clockOutTime != null) {
      date =
          DateTime(clockOutTime!.year, clockOutTime!.month, clockOutTime!.day);
    }
  }

  String get monthDayStr {
    String dateStr = _monthDayFormat.format(date!);
    return dateStr;
  }

  String get clockInTimeStr {
    return clockInTime != null ? DateFormat.Hm().format(clockInTime!) : '';
  }

  String get clockOutTimeStr {
    return clockOutTime != null ? DateFormat.Hm().format(clockOutTime!) : '';
  }

  static List<String> getElementName() {
    return ['日付', '出勤', '退勤', '時間'];
  }

  List<String> toCsvFormat() {
    List<String> csv = [
      monthDayStr,
      clockInTimeStr,
      clockOutTimeStr,
      elapsedTimeStr,
    ];

    return csv;
  }

  TimecardData copyWith() {
    return TimecardData(name,
        clockInTime: clockInTime, clockOutTime: clockOutTime);
  }

  double get elapsedTime {
    if (clockInTime == null || clockOutTime == null) {
      return 0;
    }

    double elapsed = (clockOutTime!.difference(clockInTime!).inMinutes / 60);
    if (_includingLunchTime()) {
      elapsed -= 1;
    }
    return elapsed;
  }

  String get elapsedTimeStr {
    return elapsedTime.toStringAsFixed(1);
  }

  bool _includingLunchTime() {
    bool isWeekday = (clockInTime!.weekday != DateTime.saturday ||
        clockInTime!.weekday != DateTime.sunday);

    bool includinglunchTime =
        (clockInTime!.hour <= 11 && clockOutTime!.hour >= 14);

    return isWeekday && includinglunchTime;
  }

  static List<TimecardData> create(List<AttendData> attendDataList) {
    List<TimecardData> dataList = [];
    AttendData attendData;
    TimecardData? data;
    CreateState state = CreateState.setClockIn;

    for (int i = 0; i < attendDataList.length; ++i) {
      attendData = attendDataList[i];

      switch (state) {
        // データ作成時（出勤データを期待）
        case CreateState.setClockIn:
          switch (attendData.type) {
            case AttendType.clockIn:
              data = TimecardData(attendData.name,
                  clockInTime: attendData.dateTime);
              //最後のデータならリストに追加
              if (i == attendDataList.length - 1) {
                //月末に24時超えたとき
                if (data.date!.isEndDayOfMonth) {
                  data.clockOutTime = data.date!.endOfDay;
                }
                dataList.add(data.copyWith());
                break;
              }

              state = CreateState.setClockOut;
              break;

            case AttendType.clockOut:
              data = TimecardData(attendData.name,
                  clockOutTime: attendData.dateTime);
              // 先月末から24時回った場合
              if (data.date!.isStartDayOfMonth) {
                data.clockInTime = data.date!.startOfDay;
              }
              dataList.add(data.copyWith());
              break;

            case AttendType.none:
              break;
          }
          break;

        // 退勤データ入力時（退勤データを期待）
        case CreateState.setClockOut:
          switch (attendData.type) {
            case AttendType.clockIn:
              //error('error: 退勤データが足りません');
              dataList.add(data!.copyWith());
              state = CreateState.setClockIn;
              break;

            case AttendType.clockOut:
              //data!.clockOutTime = attendData.dateTime;
              DateTime clockOutTime = attendData.dateTime;

              int dayDiff = data!.clockInTime!.difference(clockOutTime).inDays;

              if (dayDiff == 0) {
                data.clockOutTime = clockOutTime;
                dataList.add(data.copyWith());
                state = CreateState.setClockIn;
                break;
              }

              DateTime startOfDay = data.date!.startOfDay;
              DateTime endOfDay = data.date!.endOfDay;

              List<TimecardData> diffDataList = [];
              data.clockOutTime = endOfDay;

              diffDataList.add(data.copyWith());

              for (int i = 0; i < dayDiff; ++i) {
                startOfDay.add(const Duration(days: 1));
                endOfDay.add(const Duration(days: 1));
                TimecardData diffData =
                    TimecardData(attendData.name, clockInTime: startOfDay);
                if (i == dayDiff - 1) {
                  diffData.clockOutTime = clockOutTime;
                } else {
                  diffData.clockOutTime = endOfDay;
                }

                diffDataList.add(diffData);
              }

              dataList.addAll(diffDataList);
              state = CreateState.setClockIn;
              break;

            case AttendType.none:
              break;
          }
          break;
      }
    }

    return dataList;
  }
}

enum CreateState {
  setClockIn,
  setClockOut,
}
