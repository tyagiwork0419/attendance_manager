import 'package:intl/intl.dart';

import 'attend_data.dart';

class TimecardData {
  late String name;
  late DateTime? clockInTime;
  late DateTime? clockOutTime;

  final DateFormat _dateFormat = DateFormat('MM/dd(E)', 'ja');

  TimecardData(this.name, {this.clockInTime, this.clockOutTime});

  TimecardData copyWith() {
    return TimecardData(name,
        clockInTime: clockInTime, clockOutTime: clockOutTime);
  }

  String get date {
    if (clockInTime != null) {
      return _dateFormat.format(clockInTime!);
    }

    if (clockOutTime != null) {
      return _dateFormat.format(clockOutTime!);
    }

    return '';
  }

  String get elapsedTime {
    if (clockInTime == null || clockOutTime == null) {
      return '';
    }

    double elapsed = (clockOutTime!.difference(clockInTime!).inMinutes / 60);
    if (elapsed >= 8) {
      elapsed -= 1;
    }
    return elapsed.toStringAsFixed(1);
  }

  static List<TimecardData> createList(List<AttendData> attendDataList) {
    List<TimecardData> dataList = [];
    AttendData attendData;
    TimecardData? data;
    CreateState state = CreateState.setClockIn;

    for (int i = 0; i < attendDataList.length; ++i) {
      attendData = attendDataList[i];

      switch (state) {
        case CreateState.setClockIn:
          if (attendData.type == AttendType.clockIn) {
            data =
                TimecardData(attendData.name, clockInTime: attendData.dateTime);
            state = CreateState.setClockOut;
            if (i == attendDataList.length - 1) {
              dataList.add(data.copyWith());
            }
            break;
          } else if (attendData.type == AttendType.clockOut) {
            data = TimecardData(attendData.name,
                clockOutTime: attendData.dateTime);
            dataList.add(data.copyWith());
            break;
          }
          break;
        case CreateState.setClockOut:
          if (attendData.type == AttendType.clockIn) {
            dataList.add(data!.copyWith());
            data =
                TimecardData(attendData.name, clockInTime: attendData.dateTime);
            if (i == attendDataList.length - 1) {
              dataList.add(data.copyWith());
            }

            break;
          } else if (attendData.type == AttendType.clockOut) {
            data!.clockOutTime = attendData.dateTime;
            dataList.add(data.copyWith());
            state = CreateState.setClockIn;
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
