import 'dart:convert';
import 'dart:html';

import 'package:attendance_manager/models/monthly_timecard.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
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

  late MonthlyTimecard? _monthlyTimecard;
  //final List<TimecardData> _timecardDataList = [];

  final List<DataRow> _dataRowList = [];
  final DateFormat _yearMonthFormat = DateFormat('yyyy年MM月');

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

  List<DataColumn> _createDataColumnList() {
    final List<String> dataColumnLabels = TimecardData.getElementName();
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    List<DataColumn> columns = [];
    for (int i = 0; i < dataColumnLabels.length; ++i) {
      String label = dataColumnLabels[i];
      columns.add(DataColumn(label: Text(label, style: style)));
    }

    return columns;
  }

  DataRow _createDataRowByAttendData(DateTime dateTime, TimecardData data) {
    String date = data.monthDayStr;
    String clockInTime = data.clockInTimeStr;
    String clockOutTime = data.clockOutTimeStr;
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
      ErrorDialog.showErrorDialog(context, e);
    }
  }

  void _updateDataRow() {
    _dataRowList.clear();
    //_timecardDataList.clear();

    Map<int, MonthlyTimecard> monthlyTimecardMap = MonthlyTimecard.create(
        _name, _selectedDate.year, _selectedDate.month, _dataList);
    _monthlyTimecard = monthlyTimecardMap[_selectedDate.month];

    _monthlyTimecard!.dataMap.forEach((day, dailyTimecard) {
      List<TimecardData> dataList = dailyTimecard.dataList;
      for (int i = 0; i < dataList.length; ++i) {
        TimecardData data = dailyTimecard.dataList[i];
        _dataRowList.add(_createDataRowByAttendData(data.date!, data));
      }
    });
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

  Future<void> _exportData() async {
    String name = _monthlyTimecard!.name;
    String date = DateFormat('yyyy_MM').format(_monthlyTimecard!.date);
    String fileName = '${name}_${date}.csv';

    //final csv = const ListToCsvConverter(fieldDelimiter: ';')
    final header = TimecardData.getElementName();
    final rows = _monthlyTimecard!.toCsvFormat();

    if (kIsWeb == true) {
      //AnchorElement(href: 'data:text/plain;charset=utf-8,$csv')
      //csvDownload(fileName: fileName, csv: csv, utf8BOM: true);
      csvDownload(
          fileName: fileName, header: header, rows: rows, utf8BOM: true);
    }
  }

  void csvDownload(
      {required String fileName,
      required List<String> header,
      required List<List<String>> rows,
      bool utf8BOM = false}) {
    AnchorElement anchorElement;
    if (utf8BOM) {
      //　Excelで開く用に日本語を含む場合はUTF-8 BOMにする措置
      // ref. https://github.com/close2/csv/issues/41#issuecomment-899038353
      //final csv = const ListToCsvConverter(fieldDelimiter: ';').convert(
      final csv = const ListToCsvConverter().convert(
        [header, ...rows],
      );
      final bomUtf8Csv = [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
      final base64CsvBytes = base64Encode(bomUtf8Csv);
      anchorElement = AnchorElement(
        href: 'data:text/plain;charset=utf-8;base64,$base64CsvBytes',
      );
    } else {
      final csv = const ListToCsvConverter().convert(
        [header, ...rows],
      );
      anchorElement = AnchorElement(
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
                        child: DataTableView(
                            columns: _createDataColumnList(),
                            rows: _dataRowList,
                            isLoading: _isLoading),
                      )),
                  _commnadButtons(),
                ])))));
  }
}
