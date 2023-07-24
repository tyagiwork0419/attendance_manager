import 'package:attendance_manager/models/timecard_data.dart';

class DailyTimecard {
  final String name;
  final DateTime date;

  late List<TimecardData> dataList;

  DailyTimecard(this.name, int year, int month, int day)
      : date = DateTime(year, month, day) {
    dataList = [];
  }
}
