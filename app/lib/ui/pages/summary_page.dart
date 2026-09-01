import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_expandable_table/flutter_expandable_table.dart';

import '../../application/constants.dart';
import '../../models/attend_data.dart';
import '../../models/attendance_summary.dart';
import '../../models/monthly_timecard.dart';
import '../../services/attendance_service.dart';
import '../components/data_table_view.dart';
import '../components/dialogs/error_dialog.dart';
import '../components/my_app_bar.dart';

/// 月ごとの集計を並べ、最下行に年間の合計を出すページ。
class SummaryPage extends StatefulWidget {
  final AttendanceService service;
  final String title;
  final String name;

  /// この日が含まれる年を集計する。
  final DateTime dateTime;

  const SummaryPage({
    super.key,
    required this.service,
    required this.name,
    required this.dateTime,
  }) : title = '集計データ ( $name )';

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  late AttendanceService _service;
  late int _year;

  YearlySummary? _summary;
  bool _isLoading = false;

  /// データのある年。ここから外へは移動させない。
  List<int> _availableYears = [];

  /// その方向にデータのある年が残っているか。
  bool _canShift(int years) {
    if (_availableYears.isEmpty) {
      return false;
    }
    return years < 0
        ? _year > _availableYears.first
        : _year < _availableYears.last;
  }

  static const List<String> _columnNames = [
    '月',
    '総労働時間',
    '総残業時間',
    '有休使用日数',
    '休日日数',
  ];

  int get _columnCount => _columnNames.length;

  @override
  void initState() {
    super.initState();
    _service = widget.service;
    _year = widget.dateTime.year;
    _loadAvailableYears();
    _load();
  }

  /// 移動できる範囲を決めるために取る。失敗しても集計の表示は妨げない。
  Future<void> _loadAvailableYears() async {
    try {
      final List<int> years = await _service.getAvailableYears();
      if (!mounted) {
        return;
      }
      setState(() {
        _availableYears = years;
      });
    } catch (e) {
      debugPrint('listYears failed: $e');
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 年ぶんを1回で取り、12か月ぶんの集計はクライアント側で組み立てる。
      // タイムカードと同じ計算を通すので、画面ごとに数字がずれない。
      final String fileName = _service.getSheetId(DateTime(_year));
      final List<AttendData> dataList =
          await _service.getByNameForYear(fileName, widget.name);

      final List<MonthlySummary> months = [];
      for (int month = 1; month <= 12; ++month) {
        final MonthlyTimecard timecard =
            _service.createMonthlyTimecard(widget.name, _year, month, dataList);
        months.add(MonthlySummary.create(timecard, dataList,
            standardWorkHoursPerDay: _service.standardWorkHoursPerDay));
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _summary = YearlySummary(year: _year, months: months);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      ErrorDialog.showErrorDialog(context, e);
    }
  }

  void _shiftYear(int years) {
    setState(() {
      _year += years;
      _summary = null;
    });
    _load();
  }

  ExpandableTableCell _createFirstHeaderCell() {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    return DataTableView.buildCell(Text(_columnNames.first, style: style),
        color: Constants.gray);
  }

  List<ExpandableTableHeader> _createHeaders() {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    return _columnNames
        .sublist(1)
        .map((label) => ExpandableTableHeader(
            cell: DataTableView.buildCell(Text(label, style: style),
                color: Constants.gray)))
        .toList();
  }

  List<ExpandableTableRow> _createRows() {
    final YearlySummary? summary = _summary;
    if (summary == null) {
      return [];
    }

    final List<ExpandableTableRow> rows =
        summary.months.map(_createMonthRow).toList();
    rows.add(_createTotalRow(summary));

    return rows;
  }

  ExpandableTableRow _createMonthRow(MonthlySummary month) {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    // 実績のない月は淡く見せて、数字のある月を目で追いやすくする。
    final Color color = month.isEmpty ? Constants.gray : Constants.green;

    return ExpandableTableRow(
      firstCell: DataTableView.buildFirstRowCell(
          child: Text('${month.month}月', style: style), color: color),
      cells: [
        _valueCell(_hoursStr(month.workHours), color, style),
        _valueCell(_hoursStr(month.overtimeHours), color, style),
        _valueCell(_daysStr(month.paidHolidayDays), color, style),
        _valueCell(_daysStr(month.holidayDays.toDouble()), color, style),
      ],
    );
  }

  ExpandableTableRow _createTotalRow(YearlySummary summary) {
    final TextStyle? style = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontWeight: FontWeight.bold);
    const Color color = Constants.yellow;

    return ExpandableTableRow(
      firstCell:
          DataTableView.buildCell(Text('合計', style: style), color: color),
      cells: [
        _valueCell(_hoursStr(summary.workHours), color, style),
        _valueCell(_hoursStr(summary.overtimeHours), color, style),
        _valueCell(_daysStr(summary.paidHolidayDays), color, style),
        _valueCell(_daysStr(summary.holidayDays.toDouble()), color, style),
      ],
    );
  }

  ExpandableTableCell _valueCell(String text, Color color, TextStyle? style) {
    return DataTableView.buildCell(Text(text, style: style), color: color);
  }

  String _hoursStr(double hours) {
    return hours == 0 ? '' : hours.toStringAsFixed(1);
  }

  String _daysStr(double days) {
    if (days == 0) {
      return '';
    }
    // 半休があるときだけ小数を見せる。
    return days == days.roundToDouble()
        ? days.toStringAsFixed(0)
        : days.toStringAsFixed(1);
  }

  Widget _yearBar() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _yearStepButton(Icons.arrow_left, '前年', -1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$_year年',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          _yearStepButton(Icons.arrow_right, '翌年', 1),
        ],
      ),
    );
  }

  Widget _yearStepButton(IconData icon, String tooltip, int years) {
    // データのない年へは移動させない。開くと GAS 側が
    // テンプレートから空のファイルを作ってしまうため。
    final bool enabled = !_isLoading && _canShift(years);

    return Tooltip(
      message: enabled ? tooltip : 'これ以上データがありません',
      child: ElevatedButton(
        onPressed: enabled ? () => _shiftYear(years) : null,
        style: ButtonStyle(
          padding: MaterialStateProperty.all<EdgeInsets>(EdgeInsets.zero),
          minimumSize: MaterialStateProperty.all<Size>(const Size(48, 36)),
        ),
        child: Icon(icon, size: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(title: widget.title).appBar(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: Constants.allPadding,
          child: Center(
            child: Column(children: [
              SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.06,
                  child: _yearBar()),
              SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.75,
                child: Padding(
                  padding: Constants.topBottomPadding,
                  child: LayoutBuilder(
                    builder: (context, constraints) => DataTableView(
                      firstHeaderCell: _createFirstHeaderCell(),
                      headers: _createHeaders(),
                      rows: _createRows(),
                      firstColumnWidth:
                          max(110, constraints.maxWidth / _columnCount),
                      defaultsColumnWidth:
                          max(110, constraints.maxWidth / _columnCount),
                      headerHeight: 60,
                      defaultsRowHeight: 60,
                      isLoading: _isLoading,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
