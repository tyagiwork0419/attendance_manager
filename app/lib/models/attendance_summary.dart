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

  /// 総残業時間。
  ///
  /// 平日は1日あたり [Constants.standardWorkHoursPerDay] を超えた分、
  /// 休日の出勤は働いた時間の全部を数える。
  final double overtimeHours;

  /// 有休使用日数。全日は 1.0、半日は 0.5 として数える。
  final double paidHolidayDays;

  const MonthlySummary({
    required this.year,
    required this.month,
    required this.workHours,
    required this.overtimeHours,
    required this.paidHolidayDays,
  });

  bool get isEmpty =>
      workHours == 0 && overtimeHours == 0 && paidHolidayDays == 0;

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

    double overtime = 0;
    monthlyTimecard.dailyTimecards.forEach((day, dailyTimecard) {
      overtime += _overtimeOf(dailyTimecard);
    });

    return MonthlySummary(
      year: year,
      month: month,
      workHours: monthlyTimecard.sumOfElapsedTime,
      overtimeHours: overtime,
      paidHolidayDays: _countPaidHolidayDays(attendDataList, year, month),
    );
  }

  /// その日の残業時間。
  ///
  /// 休日の出勤は所定労働時間の枠外なので、働いた時間をそのまま残業とする。
  /// 平日は所定労働時間を超えた分だけを数える。
  ///
  /// 休日かどうかは [DailyTimecard.isHoliday] の判定に従う。
  /// 土日に加えて、カレンダーに予定のある日（祝日・会社の休日）も休日になる。
  static double _overtimeOf(DailyTimecard dailyTimecard) {
    if (dailyTimecard.isHoliday) {
      return dailyTimecard.elapsedTime;
    }

    final double excess =
        dailyTimecard.elapsedTime - Constants.standardWorkHoursPerDay;
    return excess > 0 ? excess : 0;
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
}
