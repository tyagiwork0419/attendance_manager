import 'dart:convert';
import 'dart:math';

import 'package:attendance_manager/models/monthly_timecard.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_expandable_table/flutter_expandable_table.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:nil/nil.dart';

import 'package:universal_html/html.dart' as html;

import '../../application/constants.dart';
import '../../models/attend_data.dart';
import '../../models/daily_timecard.dart';
import '../../models/timecard_data.dart';
import '../../services/attendance_service.dart';
import '../components/data_table_view.dart';
import '../components/dialogs/error_dialog.dart';
import '../components/my_app_bar.dart';

class TimecardPage extends StatefulWidget {
  final AttendanceService service;
  final String title;
  final String name;
  final DateTime dateTime;

  const TimecardPage(
      {super.key,
      required this.service,
      //required this.title,
      required this.name,
      required this.dateTime})
      : title = 'タイムカード ( $name )';

  @override
  State<TimecardPage> createState() => _TimecardPageState();
}

class _TimecardPageState extends State<TimecardPage> {
  late String _name;
  late AttendanceService _service;

  late MonthlyTimecard? _monthlyTimecard;

  final DateFormat _yearMonthFormat = DateFormat('yyyy年MM月');

  late DateTime _selectedDate;

  late bool _isLoading;

  List<String> get _columnNames {
    return ['日付', '出勤', '退勤', '時間', '備考'];
  }

  @override
  void initState() {
    super.initState();

    _service = widget.service;
    _isLoading = false;
    _monthlyTimecard = null;

    DateTime now = DateTime.now();

    _name = widget.name;
    _selectedDate = widget.dateTime;

    _getByName(_name, now);
  }

  ExpandableTableCell _createFirstHeaderCell() {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    String label = _columnNames.first;
    return DataTableView.buildCell(Text(label, style: style),
        color: Constants.gray);
  }

  List<ExpandableTableHeader> _createHeaders() {
    final List<String> labels = _columnNames.sublist(1);
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    List<ExpandableTableHeader> headers = [];
    for (int i = 0; i < labels.length; ++i) {
      String label = labels[i];
      headers.add(ExpandableTableHeader(
          cell: DataTableView.buildCell(Text(label, style: style),
              color: Constants.gray)));
    }

    return headers;
  }

  List<ExpandableTableRow> _createRows() {
    List<ExpandableTableRow> rows = [];
    if (_monthlyTimecard == null) {
      return rows;
    }
    _monthlyTimecard!.dataMap.forEach((day, dailyTimecard) {
      rows.add(_createRow(dailyTimecard));
    });

    rows.add(_createSum(_monthlyTimecard!));

    return rows;
  }

  ExpandableTableRow _createRow(DailyTimecard timecard) {
    Color color;
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    if (timecard.isHoliday) {
      color = Constants.red;
    } else {
      color = Constants.green;
    }

    ExpandableTableCell clockInTime = DataTableView.buildCell(
        Text(
          timecard.clockInTimeStr,
          style: style,
        ),
        color: color);
    ExpandableTableCell clockOutTime = DataTableView.buildCell(
        Text(timecard.clockOutTimeStr, style: style),
        color: color);
    ExpandableTableCell elapsedTime = DataTableView.buildCell(
        Text(timecard.elapsedTimeStr, style: style),
        color: color);

    ExpandableTableCell remarks = DataTableView.buildCell(
        Text(timecard.remarksStr, style: style),
        color: color);

    ExpandableTableCell firstCell = DataTableView.buildFirstRowCell(
        child: Text(timecard.monthDayStr, style: style), color: color);
    List<ExpandableTableCell> cells = [
      //date,
      clockInTime,
      clockOutTime,
      elapsedTime,
      remarks,
    ];

    List<ExpandableTableRow> children = [];
    List<TimecardData>? dataList = timecard.dataList;
    if (dataList.length > 1) {
      for (int i = 0; i < dataList.length; ++i) {
        var data = dataList[i];
        children.add(_createDataRowByData(data, color));
      }
    }
    ExpandableTableRow row = ExpandableTableRow(
        firstCell: firstCell, cells: cells, children: children);

    return row;
  }

  ExpandableTableRow _createDataRowByData(TimecardData data, Color color) {
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    var clockInTime = DataTableView.buildCell(
        Text(data.clockInTimeStr, style: style),
        color: color);
    var clockOutTime = DataTableView.buildCell(
        Text(data.clockOutTimeStr, style: style),
        color: color);
    var elapsedTime = DataTableView.buildCell(
        Text(data.elapsedTimeStr, style: style),
        color: color);
    var remarks = DataTableView.buildCell(nil, color: color);

    var row = ExpandableTableRow(
        firstCell: DataTableView.buildCell(nil, color: color),
        cells: [clockInTime, clockOutTime, elapsedTime, remarks]);

    return row;
  }

  ExpandableTableRow _createSum(MonthlyTimecard monthlyTimecard) {
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    Color color = Colors.green;
    var clockInTime = DataTableView.buildCell(nil, color: color);
    var clockOutTime = DataTableView.buildCell(nil, color: color);
    var elapsedTime = DataTableView.buildCell(
        Text(monthlyTimecard.sumOfElapsedTimeStr, style: style),
        color: color);
    var remarks = DataTableView.buildCell(nil, color: color);

    var row = ExpandableTableRow(
        firstCell:
            DataTableView.buildCell(Text('計', style: style), color: color),
        cells: [clockInTime, clockOutTime, elapsedTime, remarks]);

    return row;
  }

  Future<void> _getByName(String name, DateTime dateTime) async {
    String sheetId = _service.getSheetId(dateTime);
    String sheetName = _service.getSheetName(dateTime);

    try {
      _isLoading = true;
      List<AttendData> result =
          await _service.getByName(sheetId, sheetName, name);
      _isLoading = false;
      setState(() {
        _updateTimecard(result);
      });
    } catch (e) {
      _isLoading = false;
      ErrorDialog.showErrorDialog(context, e);
    }
  }

  void _updateTimecard(List<AttendData> dataList) {
    _monthlyTimecard = _service.createMonthlyTimecard(
        _name, _selectedDate.year, _selectedDate.month, dataList);
  }

  Future<void> _selectMonth() async {
    var selectedDate = await showMonthPicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(_selectedDate.year - 1),
      lastDate: DateTime(_selectedDate.year + 1),
    );

    // 選択がキャンセルされた場合はNULL
    if (selectedDate == null) return;

    // 選択されて日付で更新
    _selectedDate = selectedDate;
    setState(() {
      //_updateDataRow();
    });

    _getByName(widget.name, _selectedDate);
  }

  Widget _monthButton() {
    return Center(
        child: ElevatedButton(
      child: Text(_yearMonthFormat.format(_selectedDate)),
      onPressed: () {
        _selectMonth();
      },
    ));
  }

  Future<void> _exportData() async {
    String name = _monthlyTimecard!.name;
    String date = DateFormat('yyyy_MM').format(_monthlyTimecard!.date);
    String fileName = '${name}_$date.csv';

    final header = _columnNames;
    final rows = _monthlyTimecard!.toCsvFormat();
    final csv = const ListToCsvConverter().convert([header, ...rows]);

    if (kIsWeb == true) {
      csvDownload(fileName: fileName, csv: csv, utf8BOM: true);
    }
  }

  void csvDownload(
      {required String fileName, required String csv, bool utf8BOM = false}) {
    if (!kIsWeb) return;
    html.AnchorElement anchorElement;
    if (utf8BOM) {
      //　Excelで開く用に日本語を含む場合はUTF-8 BOMにする措置
      // ref. https://github.com/close2/csv/issues/41#issuecomment-899038353
      final bomUtf8Csv = [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
      final base64CsvBytes = base64Encode(bomUtf8Csv);
      anchorElement = html.AnchorElement(
        href: 'data:text/plain;charset=utf-8;base64,$base64CsvBytes',
      );
    } else {
      anchorElement = html.AnchorElement(
        href: 'data:text/plain;charset=utf-8,$csv',
      );
    }
    anchorElement
      ..setAttribute('download', fileName)
      ..click();
  }

  Widget _commnadButtons() {
    TextStyle? buttonTextStyle = TextStyle(
        color: Colors.white,
        fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize);

    double buttonHeight = 50;
    //double spaceMulti = 0.025;
    double buttonWidthMulti = 0.3;

    return LayoutBuilder(
        builder: (context, constraints) => Wrap(
                runAlignment: WrapAlignment.center,
                //spacing: constraints.maxWidth * spaceMulti,
                children: [
                  //if (widget.clockIn)
                  SizedBox(
                      width: constraints.maxWidth * buttonWidthMulti,
                      height: buttonHeight,
                      child: ElevatedButton(
                          onPressed: _exportData,
                          child: Text('CSV出力', style: buttonTextStyle)))
                ]));
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
                      height: MediaQuery.of(context).size.height * 0.05,
                      child: _monthButton()),
                  SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: Padding(
                        padding: Constants.topBottomPadding,
                        child: LayoutBuilder(
                            builder: (context, constraints) => DataTableView(
                                //columns: _createDataColumnList(),
                                firstHeaderCell: _createFirstHeaderCell(),
                                headers: _createHeaders(),
                                rows: _createRows(),
                                firstColumnWidth:
                                    max(120, constraints.maxWidth * 0.2),
                                defaultsColumnWidth:
                                    max(120, constraints.maxWidth * 0.2),
                                headerHeight: 60,
                                defaultsRowHeight: 60,
                                isLoading: _isLoading)),
                      )),
                  _commnadButtons(),
                ])))));
  }
}
