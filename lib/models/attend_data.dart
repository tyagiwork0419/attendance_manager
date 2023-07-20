import 'package:intl/intl.dart';

enum AttendType {
  clockIn,
  clockOut,
  none;

  String get toStr {
    switch (this) {
      case AttendType.clockIn:
        return '出勤';
      case AttendType.clockOut:
        return '退勤';

      case AttendType.none:
        return 'none';
    }
  }

  static AttendType toAttendType(String str) {
    switch (str) {
      case '出勤':
        return AttendType.clockIn;
      case '退勤':
        return AttendType.clockOut;

      default:
        return AttendType.none;
    }
  }

  static List<AttendType> get valuesWitoutNone {
    List<AttendType> list = AttendType.values.toList();
    list.remove(AttendType.none);
    return list;
  }
}

enum Status {
  normal,
  deleted,
  none;

  String get toStr {
    switch (this) {
      case Status.normal:
        return 'normal';
      case Status.deleted:
        return 'deleted';

      case Status.none:
        return 'none';
    }
  }

  static Status toStatus(String str) {
    switch (str) {
      case 'normal':
        return Status.normal;
      case 'deleted':
        return Status.deleted;

      default:
        return Status.none;
    }
  }
}

class AttendData {
  late int id = 0;
  late String name;
  late AttendType type;
  late DateTime dateTime;
  late Status status = Status.normal;

  static final DateFormat dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm:ss');
  static final DateFormat shortDateTimeFormat =
      DateFormat('MM/dd(E) HH:mm', 'ja');

  AttendData(this.name, this.type, this.dateTime);

  String get dateTimeStr {
    return dateTimeFormat.format(dateTime);
  }

  String get shortDateTimeStr {
    return shortDateTimeFormat.format(dateTime);
  }

  AttendData.fromJson(Map<String, dynamic> jsonMap)
      : id = jsonMap['id']!,
        name = jsonMap['name']!,
        type = AttendType.toAttendType(jsonMap['type']!),
        status = Status.toStatus(jsonMap['status']!) {
    dateTime = dateTimeFormat.parse(jsonMap['dateTime']);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'type': type.toStr,
      'dateTime': dateTimeStr,
      'status': status.toStr,
    };
  }
}
