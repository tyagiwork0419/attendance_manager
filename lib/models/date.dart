class Date {
  final int year;
  final int month;
  final int day;

  Date(this.year, this.month, this.day);
  static Date createFromDateTime(DateTime dateTime) {
    return Date(dateTime.year, dateTime.month, dateTime.day);
  }

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      other is Date &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hashAll([year, month, day]);
}
