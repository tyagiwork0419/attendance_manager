import 'package:intl/intl.dart';

import 'attend_data.dart';

/// 出勤と退勤が交互に並ぶことを保つための判定。
///
/// ホーム画面の打刻ボタンとタイムカードの編集の両方から使う。
/// 判定の基準を1か所にまとめておかないと、入口ごとに挙動がずれてしまう。
class PunchSequence {
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  /// [dataList] に [dateTime] の [type] を足したとき、同じ種類が隣り合うか調べる。
  ///
  /// 問題があれば利用者向けの理由を返し、無ければ null を返す。
  /// [dataList] は当日ぶんに限らなくてよい。同じ日のものだけを見て判定する。
  static String? findConflict({
    required List<AttendData> dataList,
    required String name,
    required AttendType type,
    required DateTime dateTime,
  }) {
    // 有休は出退勤の並びとは独立しているので対象外。
    if (type != AttendType.clockIn && type != AttendType.clockOut) {
      return null;
    }

    List<AttendData> sequence = dataList
        .where((AttendData data) =>
            data.name == name &&
            (data.type == AttendType.clockIn ||
                data.type == AttendType.clockOut) &&
            _isSameDay(data.dateTime, dateTime))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // 時刻を選び直して既存の打刻の間に入れることもできるため、
    // 直前だけでなく直後も確認する。
    AttendData? previous;
    AttendData? next;
    for (AttendData data in sequence) {
      if (data.dateTime.isAfter(dateTime)) {
        next ??= data;
      } else {
        previous = data;
      }
    }

    AttendData? conflict;
    if (previous != null && previous.type == type) {
      conflict = previous;
    } else if (next != null && next.type == type) {
      conflict = next;
    }

    if (conflict == null) {
      return null;
    }

    String needed = type == AttendType.clockIn
        ? AttendType.clockOut.toStr
        : AttendType.clockIn.toStr;

    return '${_timeFormat.format(conflict.dateTime)} に${type.toStr}が記録されています。\n'
        '先に$neededを記録してください。';
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
