extension DateTimeExtension on DateTime {
  DateTime get startOfDay {
    DateTime startOfDay = DateTime(year, month, day, 0, 0);
    return startOfDay;
  }

  DateTime get endOfDay {
    DateTime startOfDay = DateTime(year, month, day, 23, 59);
    return startOfDay;
  }

  bool isSameDay(DateTime other) {
    return difference(other).inDays == 0;
  }

  bool get isEndDayOfMonth {
    return day == lastDayOfMonth;
  }

  bool get isStartDayOfMonth {
    return day == 1;
  }

  int get lastDayOfMonth {
    DateTime lastDate =
        DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
    return lastDate.day;
  }

  bool get isWeekday {
    return (weekday != DateTime.saturday && weekday != DateTime.sunday);
  }
}
