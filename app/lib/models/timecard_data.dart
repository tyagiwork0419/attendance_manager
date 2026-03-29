//import 'package:intl/intl.dart';
import 'package:intl/intl.dart';

import 'attend_data.dart';
import 'datetime_utility.dart';

class TimecardData {
  late String name;

  late DateTime? clockInTime;
  late DateTime? clockOutTime;

  late List<String> errors;
  late List<String> remarks;

  final DateFormat _monthDayFormat = DateFormat('MM/dd(E)', 'ja');

  static const String clockInErrorStr = '出勤エラー';
  static const String clockOutErrorStr = '退勤エラー';

  TimecardData(this.name,
      //{this.date, this.clockInTime, this.clockOutTime, this.errors}) {
      {this.clockInTime,
      this.clockOutTime,
      List<String>? errors,
      List<String>? remarks})
      : errors = errors ?? [],
        remarks = remarks ?? [];

  DateTime? get date {
    if (clockInTime != null) {
      return DateTime(clockInTime!.year, clockInTime!.month, clockInTime!.day);
    } else if (clockOutTime != null) {
      return DateTime(
          clockOutTime!.year, clockOutTime!.month, clockOutTime!.day);
    }

    return null;
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

  List<String> toCsvFormat() {
    List<String> csv = [
      monthDayStr,
      clockInTimeStr,
      clockOutTimeStr,
      elapsedTimeStr,
      remarksStr,
    ];

    return csv;
  }

  TimecardData copyWith() {
    return TimecardData(name,
        clockInTime: clockInTime,
        clockOutTime: clockOutTime,
        remarks: remarks,
        errors: errors);
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

  String get remarksStr {
    String str = '';
    if (remarks.isNotEmpty) {
      for (var remark in remarks) {
        str += '$remark, ';
      }
    }

    if (errors.isNotEmpty) {
      for (var error in errors) {
        str += '$error, ';
      }
    }

    if (str.length >= 2) {
      str = str.substring(0, str.length - 2);
    }

    return str;
  }

/*
  String get errorsStr {
    String str = '';
    if (errors.isNotEmpty) {
      for (var error in errors) {
        str += '$error, ';
      }

      str = str.substring(0, str.length - 2);
    }

    return str;
  }
  */

  bool _includingLunchTime() {
    bool isWeekday = clockInTime!.isWeekday;
    bool includinglunchTime =
        (clockInTime!.hour <= 11 && clockOutTime!.hour >= 14);

    return isWeekday && includinglunchTime;
  }

  static void addData(List<TimecardData> list, CreateState state) {}

  static TimecardData getPaidHolidayData(AttendData attendData) {
    DateTime dt = attendData.dateTime;
    DateTime clockInTime = DateTime(dt.year, dt.month, dt.day, 0, 0, 0);
    DateTime clockOutTime = DateTime(dt.year, dt.month, dt.day, 0, 0, 0);

    return TimecardData(attendData.name,
        clockInTime: clockInTime,
        clockOutTime: clockOutTime,
        remarks: attendData.remarks);
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
            case AttendType.paidHoliday:
              data = getPaidHolidayData(attendData);
              dataList.add(data.copyWith());
              break;
            case AttendType.clockIn:
              data = TimecardData(attendData.name,
                  clockInTime: attendData.dateTime);
              //最後のデータならリストに追加
              if (i == attendDataList.length - 1) {
                /*
                //月末に24時超えたとき
                if (data.date!.isEndDayOfMonth) {
                  data.clockOutTime = data.date!.endOfDay;
                }
                */
                data.errors.add(clockOutErrorStr);
                //data.errors!.add('退勤時間未入力');
                dataList.add(data.copyWith());
                break;
              }

              state = CreateState.setClockOut;
              break;

            case AttendType.clockOut:

              //error('error: 出勤データが足りません');
              data = TimecardData(attendData.name,
                  clockOutTime: attendData.dateTime);
              data.errors.add(clockInErrorStr);

              /*
              // 先月末から24時回った場合
              if (data.date!.isStartDayOfMonth) {
                data.clockInTime = data.date!.startOfDay;
              }
              */
              dataList.add(data.copyWith());
              break;

            case AttendType.none:
              break;
          }
          break;

        // 退勤データ入力時（退勤データを期待）
        case CreateState.setClockOut:
          switch (attendData.type) {
            case AttendType.paidHoliday:
              data = getPaidHolidayData(attendData);
              dataList.add(data.copyWith());
              state = CreateState.setClockIn;
              break;

            case AttendType.clockIn:
              //error('error: 退勤データが足りません');
              data!.errors.add(clockOutErrorStr);
              dataList.add(data.copyWith());

              data = TimecardData(attendData.name,
                  clockInTime: attendData.dateTime);
              //最後のデータならリストに追加
              if (i == attendDataList.length - 1) {
                /*
                //月末に24時超えたとき
                if (data.date!.isEndDayOfMonth) {
                  data.clockOutTime = data.date!.endOfDay;
                }
                */
                data.errors.add(clockOutErrorStr);
                dataList.add(data.copyWith());
                break;
              }
              state = CreateState.setClockOut;
              break;

            case AttendType.clockOut:
              //data!.clockOutTime = attendData.dateTime;
              DateTime clockOutTime = attendData.dateTime;

              int dayDiff = data!.clockInTime!.difference(clockOutTime).inDays;

              // clockInTimeとclockOutTimeが同日か確認
              if (dayDiff == 0) {
                data.clockOutTime = clockOutTime;
                dataList.add(data.copyWith());

                state = CreateState.setClockIn;
                break;
              } else {
                data.errors.add('退勤時間未入力');
                dataList.add(data.copyWith());

                data = TimecardData(attendData.name,
                    clockOutTime: attendData.dateTime);

                /*
              // 先月末から24時回った場合
              if (data.date!.isStartDayOfMonth) {
                data.clockInTime = data.date!.startOfDay;
              }
              */
                data.errors.add('出勤時間未入力');
                dataList.add(data.copyWith());

                state = CreateState.setClockIn;
                break;
              }

            /*
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
              */
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
