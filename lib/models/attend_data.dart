import 'package:intl/intl.dart';

enum AttendType { clockIn, clockOut, none }

extension AttendTypeExtension on AttendType {
  String get toStr {
    switch (this) {
      case AttendType.clockIn:
        return '出勤';
      case AttendType.clockOut:
        return '退勤';

      case AttendType.none:
        return '';
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
}

enum Status { normal, deleted, none }

extension StatusExtension on Status {
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

  //final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  //final DateFormat _timeFormat = DateFormat('HH:mm:ss');
  final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm:ss');

  AttendData(this.name, this.type, this.dateTime);

/*
  DateTime get time {
    return DateTime(0, 0, 0, dateTime.hour, dateTime.minute, dateTime.second);
  }

  DateTime get date {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }
  */

/*
  String get timeStr {
    return _timeFormat.format(dateTime);
  }

  String get dateStr {
    return _dateFormat.format(dateTime);
  }
  */

  String get dateTimeStr {
    return _dateTimeFormat.format(dateTime);
  }

  AttendData.fromJson(Map<String, dynamic> jsonMap)
      : id = jsonMap['id']!,
        name = jsonMap['name']!,
        type = AttendTypeExtension.toAttendType(jsonMap['type']!),
        status = StatusExtension.toStatus(jsonMap['status']!) {
    dateTime = _dateTimeFormat.parse(jsonMap['dateTime']);
    //dateTime = _dateTimeFormat.parse(jsonMap['date'] + ' ' + jsonMap['time']);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'type': type.toStr,
      'dateTime': dateTimeStr,
      //'time': timeStr,
      'status': status.toStr,
    };
  }
}
