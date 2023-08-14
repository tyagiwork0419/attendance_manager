import 'package:intl/intl.dart';

enum AttendType {
  clockIn,
  clockOut,
  paidHoliday,
  none;

  String get toStr {
    switch (this) {
      case AttendType.clockIn:
        return '出勤';
      case AttendType.clockOut:
        return '退勤';
      case AttendType.paidHoliday:
        return '有休';

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
      case '有休':
        return AttendType.paidHoliday;

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

enum PaidHolidayType {
  full,
  half,
  none;

  String get toStr {
    switch (this) {
      case PaidHolidayType.full:
        return '有休(全日)';
      case PaidHolidayType.half:
        return '有休(半日)';

      case PaidHolidayType.none:
        return 'none';
    }
  }

  static PaidHolidayType toPaidHolidayType(String str) {
    switch (str) {
      case '有休(全日)':
        return PaidHolidayType.full;
      case '有休(半日)':
        return PaidHolidayType.half;

      default:
        return PaidHolidayType.none;
    }
  }
}

class AttendData {
  late int id = 0;
  late String name;
  late AttendType type;
  late DateTime dateTime;
  late Status status = Status.normal;
  late List<String>? remarks;

  static final DateFormat dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm:ss');
  static final DateFormat shortDateTimeFormat =
      DateFormat('MM/dd(E) HH:mm', 'ja');

  AttendData(this.name, this.type, this.dateTime,
      {this.status = Status.normal, List<String>? remarks})
      : remarks = remarks ?? [];

  String get dateTimeStr {
    return dateTimeFormat.format(dateTime);
  }

  String get shortDateTimeStr {
    return shortDateTimeFormat.format(dateTime);
  }

  String remarksToString(String divider) {
    if (remarks!.isEmpty) {
      return '';
    }

    String str = '';
    for (var remark in remarks!) {
      str += '$remark$divider';
    }

    str = str.substring(0, str.length - divider.length);

    return str;
  }

  AttendData.fromJson(Map<String, dynamic> jsonMap)
      : id = jsonMap['id']!,
        name = jsonMap['name']!,
        type = AttendType.toAttendType(jsonMap['type']!),
        status = Status.toStatus(
          jsonMap['status']!,
        ) {
    dateTime = dateTimeFormat.parse(jsonMap['dateTime']);
    String remarks = jsonMap['remarks'] as String;
    this.remarks = remarks.split(',');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'name': name,
      'type': type.toStr,
      'dateTime': dateTimeStr,
      'status': status.toStr,
      'remarks': remarksToString(','),
    };
  }
}
