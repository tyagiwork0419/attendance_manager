import 'package:intl/intl.dart';

enum AttendType { clockIn, clockOut }

extension AttendTypeExtension on AttendType {
  int get toInt {
    switch (this) {
      case AttendType.clockIn:
        return 1;
      case AttendType.clockOut:
        return 2;
    }
  }
}

class AttendData {
  late int id;
  late DateTime time;
  late AttendType type;
  late DateTime updateTime;

  AttendData(this.id, this.time, this.type, this.updateTime);

  Map<String, String> toJson() {
    DateFormat outputFormat = DateFormat('yyyy/MM/dd hh:mm:ss');

    return {
      'id': id.toString(),
      'time': outputFormat.format(time),
      'type': type.toInt.toString(),
      'update_time': outputFormat.format(updateTime)
    };
  }
}
