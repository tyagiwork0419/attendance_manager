import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

import '../application/constants.dart';
import '../models/attend_data.dart';
import '../models/timecard_data.dart';
import '../services/attendance_service.dart';
import 'components/dialogs/error_dialog.dart';

class TimecardPage extends StatefulWidget {
  final AttendanceService service;
  final String title;
  final String name;
  final DateTime dateTime;

  const TimecardPage(
      {super.key,
      required this.service,
      required this.title,
      required this.name,
      required this.dateTime});

  @override
  State<TimecardPage> createState() => _TimecardPageState();
}

class _TimecardPageState extends State<TimecardPage> {
  //final sheetId = '2023年';
  late AttendanceService _service;
  List<AttendData> _dataList = [];
  List<TimecardData> _timecardDataList = [];

  final EdgeInsets topBottomPadding = const EdgeInsets.fromLTRB(
      0, Constants.paddingMiddium, 0, Constants.paddingMiddium);
  final EdgeInsets allPadding = const EdgeInsets.all(Constants.paddingMiddium);

  final Duration wait100Milliseconds = const Duration(milliseconds: 100);

  final List<DataRow> _dataRowList = [];
  final DateFormat _yearMonthFormat = DateFormat('yyyy/MM');

  late DateTime _selectedDate;

  late bool _isLoading;

  @override
  void initState() {
    super.initState();

    _service = widget.service;
    _isLoading = false;

    DateTime now = DateTime.now();

    String name = widget.name;
    _selectedDate = widget.dateTime;

    _getByName(name, now);
  }

  void _showErrorDialog(String error) {
    debugPrint(error);
    showDialog<void>(
        context: context,
        builder: (_) => ErrorDialog(title: '通信エラー', content: error));
  }

  List<DataColumn> _createDataColumnList() {
    final List<String> dataColumnLabels = ['日付', '名前', '出勤', '退勤', '時間'];
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    List<DataColumn> columns = [];
    for (int i = 0; i < dataColumnLabels.length; ++i) {
      String label = dataColumnLabels[i];
      columns.add(DataColumn(label: Text(label, style: style)));
    }

    return columns;
  }

  //DataRow _createDataRowByAttendData(AttendData data) {
  DataRow _createDataRowByAttendData(TimecardData data) {
    String date = data.date.toString();
    String name = data.name;
    String clockInTime = data.clockInTime == null
        ? ''
        : DateFormat.Hm().format(data.clockInTime!);
    String clockOutTime = data.clockOutTime == null
        ? ''
        : DateFormat.Hm().format(data.clockOutTime!);
    String elapsedTime = data.elapsedTime;
    Color color = const Color.fromARGB(255, 210, 255, 212);
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;

/*
    switch (data.type) {
      case AttendType.clockIn:
        color = const Color.fromARGB(255, 210, 255, 212);
        break;
      case AttendType.clockOut:
        color = const Color.fromARGB(255, 255, 213, 227);
        break;

      default:
        color = Colors.white;
    }
    */

    DataRow dataRow = DataRow(
        color: MaterialStateColor.resolveWith((states) => color),
        cells: [
          DataCell(Text(date, style: style)),
          DataCell(Text(name, style: style)),
          DataCell(Text(clockInTime, style: style)),
          DataCell(Text(clockOutTime, style: style)),
          DataCell(Text(elapsedTime, style: style)),
          /*
          DataCell(IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              debugPrint('presseed');
              bool? delete = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) {
                    return const DeleteDialog();
                  });

              if (delete!) {
                _deleteRow(data);
              }
            },
          )),
          */
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

      result.sort((a, b) {
        return a.dateTime.compareTo(b.dateTime);
      });
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
    _timecardDataList = TimecardData.createList(_dataList);
    for (int i = 0; i < _timecardDataList.length; ++i) {
      _dataRowList.add(_createDataRowByAttendData(_timecardDataList[i]));
    }
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

  @override
  Widget build(BuildContext context) {
    TextStyle? buttonTextStyle = TextStyle(
        color: Colors.white,
        fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize);

    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            Padding(
                padding: const EdgeInsets.only(right: 30),
                child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('version: ${Constants.version}',
                        style: Constants.getVersionTextStyle(context))))
          ],
        ),
        body: SingleChildScrollView(
            child: Padding(
                padding: allPadding,
                child: Center(
                    child: Column(children: [
                  SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.05,
                      child: Center(
                          child: ElevatedButton(
                        child: Text(_yearMonthFormat.format(_selectedDate)),
                        onPressed: () {
                          _selectMonth();
                        },
                      ))),
                  SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.8,
                      child: Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: [
                            Container(
                                decoration: BoxDecoration(border: Border.all()),
                                child: SingleChildScrollView(
                                    child: DataTable(
                                        sortColumnIndex: 1,
                                        sortAscending: true,
                                        headingRowHeight: 60,
                                        dataRowMaxHeight: 60,
                                        dataRowMinHeight: 60,
                                        border: TableBorder.all(),
                                        headingRowColor:
                                            MaterialStateColor.resolveWith(
                                                (states) =>
                                                    const Color.fromARGB(
                                                        255, 218, 218, 218)),
                                        columns: _createDataColumnList(),
                                        rows: _dataRowList))),
                            if (_isLoading)
                              const Stack(fit: StackFit.expand, children: [
                                ColoredBox(
                                  color: Colors.black26,
                                ),
                                Center(child: CircularProgressIndicator()),
                              ])
                          ])),
                  /*
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Expanded(
                        child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                                onPressed: () {},
                                child: Text('出勤', style: buttonTextStyle)))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                                onPressed: () {},
                                child: Text('退勤', style: buttonTextStyle)))),
                  ])*/
                ])))));
  }
}
