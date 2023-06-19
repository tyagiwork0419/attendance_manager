import 'package:intl/intl.dart';

enum AttendType { clockIn, clockOut }

extension AttendTypeExtension on AttendType {
  String get toInt {
    switch (this) {
      case AttendType.clockIn:
        return '出勤';
      case AttendType.clockOut:
        return '退勤';
    }
  }
}

class AttendData {
  late int id;
  late String name;
  late DateTime time;
  late AttendType type;
  late DateTime updateTime;

  AttendData(this.id, this.name, this.time, this.type, this.updateTime);

  Map<String, String> toJson() {
    DateFormat outputFormat = DateFormat('yyyy/MM/dd hh:mm:ss');

    return {
      'id': id.toString(),
      'name': name,
      'time': outputFormat.format(time),
      'type': type.toInt.toString(),
      'update_time': outputFormat.format(updateTime)
    };
  }
}