import 'package:intl/intl.dart';

enum AttendType { clockIn, clockOut }

extension AttendTypeExtension on AttendType {
  String get toStr {
    switch (this) {
      case AttendType.clockIn:
        return '出勤';
      case AttendType.clockOut:
        return '退勤';
    }
  }
}

enum Status { normal, deleted}

extension StatusExtension on Status{
  String get toStr {
    switch (this) {
      case Status.normal:
        return 'normal';
      case Status.deleted:
        return 'deleted';
    }
  }
}
class AttendData {
  late int id;
  late String name;
  late AttendType type;
  late DateTime time;
  late Status status;

  AttendData(this.id, this.name, this.type, this.time, this.status);

  Map<String, String> toJson() {
    DateFormat outputFormat = DateFormat('yyyy/MM/dd hh:mm:ss');

    return {
      'id': id.toString(),
      'name': name,
      'type': type.toStr,
      'time': outputFormat.format(time),
      'status': status.toStr,
    };
  }
}
