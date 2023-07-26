import 'package:attendance_manager/models/monthly_timecard.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

import '../../application/constants.dart';
import '../../models/attend_data.dart';
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
  //final sheetId = '2023年';
  late String _name;
  late AttendanceService _service;
  final List<AttendData> _dataList = [];
  final List<TimecardData> _timecardDataList = [];

  final List<DataRow> _dataRowList = [];
  final DateFormat _yearMonthFormat = DateFormat('yyyy年MM月');
  final DateFormat _monthDayFormat = DateFormat('MM/dd(E)', 'ja');

  late DateTime _selectedDate;

  late bool _isLoading;

  @override
  void initState() {
    super.initState();

    _service = widget.service;
    _isLoading = false;

    DateTime now = DateTime.now();

    _name = widget.name;
    _selectedDate = widget.dateTime;

    _getByName(_name, now);
  }

  void _showErrorDialog(String error) {
    debugPrint(error);
    showDialog<void>(
        context: context,
        builder: (_) => ErrorDialog(title: '通信エラー', content: error));
  }

  List<DataColumn> _createDataColumnList() {
    final List<String> dataColumnLabels = ['日付', '出勤', '退勤', '時間'];
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    List<DataColumn> columns = [];
    for (int i = 0; i < dataColumnLabels.length; ++i) {
      String label = dataColumnLabels[i];
      columns.add(DataColumn(label: Text(label, style: style)));
    }

    return columns;
  }

  DataRow _createDataRowByAttendData(DateTime dateTime, TimecardData data) {
    String date = _monthDayFormat.format(dateTime);
    String clockInTime = data.clockInTime == null
        ? ''
        : DateFormat.Hm().format(data.clockInTime!);
    String clockOutTime = data.clockOutTime == null
        ? ''
        : DateFormat.Hm().format(data.clockOutTime!);
    String elapsedTime = data.elapsedTime;
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    Color color;

    switch (dateTime.weekday) {
      case DateTime.saturday:
      case DateTime.sunday:
        color = Constants.red;
        break;

      default:
        color = Constants.green;
    }

    DataRow dataRow = DataRow(
        color: MaterialStateColor.resolveWith((states) => color),
        cells: [
          DataCell(Text(date, style: style)),
          DataCell(Text(clockInTime, style: style)),
          DataCell(Text(clockOutTime, style: style)),
          DataCell(Text(elapsedTime, style: style)),
        ]);

    return dataRow;
  }

  Future<void> _getByName(String name, DateTime dateTime) async {
    String sheetId = _service.getSheetId(dateTime);
    String sheetName = _service.getSheetName(dateTime);

    try {
      _isLoading = true;
      List<AttendData> result =
          await _service.getByName(sheetId, sheetName, name);

      _dataList.clear();
      _dataList.addAll(result);
      _isLoading = false;
      setState(() {
        _updateDataRow();
      });
    } catch (e) {
      _isLoading = false;
      _showErrorDialog(e.toString());
    }
  }

  void _updateDataRow() {
    _dataRowList.clear();
    _timecardDataList.clear();

    Map<int, MonthlyTimecard> monthlyTimecardMap = MonthlyTimecard.create(
        _name, _selectedDate.year, _selectedDate.month, _dataList);

    monthlyTimecardMap[_selectedDate.month]!
        .dataMap
        .forEach((day, dailyTimecard) {
      List<TimecardData> dataList = dailyTimecard.dataList;
      for (int i = 0; i < dataList.length; ++i) {
        TimecardData data = dailyTimecard.dataList[i];
        _dataRowList.add(_createDataRowByAttendData(data.date!, data));
      }

      if (dataList.isEmpty) {
        _dataRowList.add(_createDataRowByAttendData(
            dailyTimecard.date, TimecardData(dailyTimecard.name)));
      }
    });
  }

  Future<void> _getByDateTime(DateTime dateTime) async {
    String sheetId = _service.getSheetId(dateTime);
    String sheetName = _service.getSheetName(dateTime);

    try {
      _isLoading = true;
      List<AttendData> result =
          await _service.getByDateTime(sheetId, sheetName, dateTime);
      _dataList.clear();
      _dataList.addAll(result);
      _isLoading = false;
      setState(() {
        _updateDataRow();
      });
    } catch (e) {
      _isLoading = false;
      _showErrorDialog(e.toString());
    }
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
    _dataList.clear();
    setState(() {
      _updateDataRow();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: MyAppBar(title: widget.title, version: Constants.version)
            .appBar(context),
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
                      height: MediaQuery.of(context).size.height * 0.8,
                      child: Padding(
                        padding: Constants.topBottomPadding,
                        child: DataTableView(
                            columns: _createDataColumnList(),
                            rows: _dataRowList,
                            isLoading: _isLoading),
                      )),
                ])))));
  }
}
