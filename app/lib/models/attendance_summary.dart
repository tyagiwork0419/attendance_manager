import '../application/constants.dart';
import 'attend_data.dart';
import 'daily_timecard.dart';
import 'monthly_timecard.dart';

/// 1か月ぶんの集計。
class MonthlySummary {
  final int year;
  final int month;

  /// 総労働時間。休憩を差し引いた実働の合計。
  final double workHours;

  /// 総残業時間。総労働時間から、その月の所定労働時間を引いた値。
  ///
  /// 所定に届かなかった月は負になる。算出の詳細は [_overtime] を参照。
  final double overtimeHours;

  /// 有休使用日数。全日は 1.0、半日は 0.5 として数える。
  final double paidHolidayDays;

  /// 休日日数。その日の労働時間（[DailyTimecard.elapsedTime]）が
  /// 0 時間の日を休日として数える。土日祝だけでなく、有休を取った日や
  /// 単に打刻のなかった日も含む。
  final int holidayDays;

  const MonthlySummary({
    required this.year,
    required this.month,
    required this.workHours,
    required this.overtimeHours,
    required this.paidHolidayDays,
    required this.holidayDays,
  });

  /// その月に記録が何も無いか。
  ///
  /// 残業時間は所定労働時間に届かないと負になるので、判定には使わない。
  bool get isEmpty => workHours == 0 && paidHolidayDays == 0;

  /// [monthlyTimecard] と、その月の生データから集計を組み立てる。
  ///
  /// 労働時間はタイムカードの計算をそのまま使う。休憩の扱いなどの規則が
  /// 画面と集計で食い違わないようにするため、ここでは計算し直さない。
  factory MonthlySummary.create(
    MonthlyTimecard monthlyTimecard,
    List<AttendData> attendDataList,
  ) {
    final int year = monthlyTimecard.date.year;
    final int month = monthlyTimecard.date.month;

    final double workHours = monthlyTimecard.sumOfElapsedTime;
    final double paidHolidayDays =
        _countPaidHolidayDays(attendDataList, year, month);

    return MonthlySummary(
      year: year,
      month: month,
      workHours: workHours,
      overtimeHours: _overtime(monthlyTimecard, workHours, paidHolidayDays),
      paidHolidayDays: paidHolidayDays,
      holidayDays: _countHolidayDays(monthlyTimecard, workHours, paidHolidayDays),
    );
  }

  /// 労働時間が 0 時間の日を数える。
  ///
  /// 記録が何も無い月は 0 にする（[_overtime] と同じ理由）。そうしないと、
  /// まだ来ていない月まで丸ごと休日として数えてしまう。
  static int _countHolidayDays(
    MonthlyTimecard monthlyTimecard,
    double workHours,
    double paidHolidayDays,
  ) {
    if (workHours == 0 && paidHolidayDays == 0) {
      return 0;
    }

    int days = 0;
    monthlyTimecard.dailyTimecards.forEach((day, DailyTimecard dailyTimecard) {
      if (dailyTimecard.elapsedTime == 0) {
        days++;
      }
    });
    return days;
  }

  /// 総労働時間から、その月の所定労働時間を差し引いた値。
  ///
  ///     総労働時間 − 休日以外の日数 × [Constants.standardWorkHoursPerDay]
  ///
  /// 休日は差し引く日数に入らないので、休日に働いた時間はそのまま残る。
  ///
  /// 所定労働時間に届かなかった月は負の値になる。有休を取った日も
  /// 「休日以外の日数」に数えるため、有休の多い月は負に振れる。
  ///
  /// 記録が何も無い月だけは 0 にする。そうしないと、まだ来ていない月まで
  /// 所定労働時間ぶんの不足として並んでしまう。
  static double _overtime(
    MonthlyTimecard monthlyTimecard,
    double workHours,
    double paidHolidayDays,
  ) {
    if (workHours == 0 && paidHolidayDays == 0) {
      return 0;
    }

    return workHours -
        _workingDaysOf(monthlyTimecard) * Constants.standardWorkHoursPerDay;
  }

  /// その月の休日以外の日数。
  ///
  /// 休日かどうかは [DailyTimecard.isHoliday] の判定に従う。
  /// 土日に加えて、カレンダーに予定のある日（祝日・会社の休日）も休日になる。
  static int _workingDaysOf(MonthlyTimecard monthlyTimecard) {
    int days = 0;
    monthlyTimecard.dailyTimecards.forEach((day, DailyTimecard dailyTimecard) {
      if (!dailyTimecard.isHoliday) {
        days++;
      }
    });
    return days;
  }

  /// 有休の日数を数える。
  ///
  /// 種別は打刻時に remarks へ入れているので、そこから全日か半日かを判断する。
  static double _countPaidHolidayDays(
      List<AttendData> attendDataList, int year, int month) {
    double days = 0;

    for (final AttendData data in attendDataList) {
      if (data.type != AttendType.paidHoliday) {
        continue;
      }
      if (data.dateTime.year != year || data.dateTime.month != month) {
        continue;
      }

      days += _daysOf(data);
    }

    return days;
  }

  static double _daysOf(AttendData data) {
    final List<String> remarks = data.remarks ?? [];
    for (final String remark in remarks) {
      switch (PaidHolidayType.toPaidHolidayType(remark)) {
        case PaidHolidayType.full:
          return 1.0;
        case PaidHolidayType.half:
          return 0.5;
        case PaidHolidayType.none:
          break;
      }
    }

    // 種別が読み取れない古いデータは全日として扱う。
    return 1.0;
  }
}

/// 1年ぶんの集計。
class YearlySummary {
  final int year;
  final List<MonthlySummary> months;

  const YearlySummary({required this.year, required this.months});

  double get workHours =>
      months.fold(0, (sum, m) => sum + m.workHours);

  double get overtimeHours =>
      months.fold(0, (sum, m) => sum + m.overtimeHours);

  double get paidHolidayDays =>
      months.fold(0, (sum, m) => sum + m.paidHolidayDays);

  int get holidayDays => months.fold(0, (sum, m) => sum + m.holidayDays);
}
