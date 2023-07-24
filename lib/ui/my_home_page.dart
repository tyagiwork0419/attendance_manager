import 'dart:async';

import 'package:attendance_manager/ui/timecard_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../models/attend_data.dart';
import '../services/gas_client.dart';
import '../services/attendance_service.dart';
import '../application/constants.dart';

import 'components/data_table_view.dart';
import 'components/dialogs/datetime_picker_dialog.dart';
import 'components/dialogs/delete_dialog.dart';
import 'components/dialogs/error_dialog.dart';
import 'components/my_app_bar.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<DataRow> _dataRowList = [];

  late GasClient _gasClient;
  late AttendanceService _attendanceService;

  final List<String> _nameList = <String>[
    //'test',
    '八木',
    '大滝',
    '山本',
    '広瀬',
    '坂下',
    '西本'
  ];

  final EdgeInsets topBottomPadding = const EdgeInsets.fromLTRB(
      0, Constants.paddingMiddium, 0, Constants.paddingMiddium);
  final EdgeInsets allPadding = const EdgeInsets.all(Constants.paddingMiddium);

  final ScrollController _scrollController = ScrollController();
  final Duration wait100Milliseconds = const Duration(milliseconds: 100);

  //String _clockString = '';
  late DateTime _clockDate;
  late DateTime _selectedDate;
  //final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');

  final List<AttendData> _dataList = [];
  late bool _isLoading;

  int _choiceIndex = 0;
  String get _chooseName {
    return _nameList[_choiceIndex];
  }

  @override
  void initState() {
    super.initState();
    //_dropdownValue = _nameList.first;
    _gasClient = GasClient(Constants.clientId, Constants.clientSecret,
        Constants.refreshToken, Constants.tokenUrl, Constants.apiUrl);
    _attendanceService = AttendanceService(_gasClient);

    initializeDateFormatting(Constants.locale);

    DateTime now = DateTime.now();
    //_clockString = AttendData.dateTimeFormat.format(now);
    _clockDate = now;
    _selectedDate = now;
    _isLoading = false;

    Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
      DateTime now = DateTime.now();
      _clockDate = now;

      //_clockString = AttendData.dateTimeFormat.format(now);
      setState(() {});
    });

    _getByDateTime(now);
  }

  List<DataColumn> _createDataColumnList() {
    List<String> dataColumnLabels = ['名前', '時刻', '種類', '削除'];
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    List<DataColumn> columns = [];
    for (int i = 0; i < dataColumnLabels.length; ++i) {
      String label = dataColumnLabels[i];
      columns
          .add(DataColumn(label: Expanded(child: Text(label, style: style))));
    }

    return columns;
  }

  DataRow _createDataRowByAttendData(AttendData data) {
    String name = data.name;
    String dateTime = data.shortDateTimeStr;
    String type = data.type.toStr;
    Color color;
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;

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

    DataRow dataRow = DataRow(
        color: MaterialStateColor.resolveWith((states) => color),
        cells: [
          DataCell(Text(name, style: style)),
          DataCell(Text(dateTime, style: style)),
          DataCell(Text(type, style: style)),
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
        ]);

    return dataRow;
  }

  void _updateDataRow() {
    _dataRowList.clear();
    for (int i = 0; i < _dataList.length; ++i) {
      _dataRowList.add(_createDataRowByAttendData(_dataList[i]));
    }
  }

  void _scrollToEnd() {
    _scrollController.animateTo(_scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100), curve: Curves.ease);
  }

  Future<void> _getByDateTime(DateTime dateTime) async {
    String sheetId = _attendanceService.getSheetId(dateTime);
    String sheetName = _attendanceService.getSheetName(dateTime);

    try {
      _isLoading = true;
      List<AttendData> result =
          await _attendanceService.getByDateTime(sheetId, sheetName, dateTime);
      _dataList.clear();
      _dataList.addAll(result);
      _isLoading = false;
      setState(() {
        _updateDataRow();
      });
      await Future.delayed(wait100Milliseconds);
      setState(() {
        _scrollToEnd();
      });
    } catch (e) {
      _isLoading = false;
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String error) {
    debugPrint(error);
    showDialog<void>(
        context: context,
        builder: (_) => ErrorDialog(title: '通信エラー', content: error));
  }

  Future<void> _deleteRow(AttendData data) async {
    try {
      _isLoading = true;
      debugPrint('delete row');
      String sheetId = _attendanceService.getSheetId(data.dateTime);
      String sheetName = _attendanceService.getSheetName(data.dateTime);
      data.status = Status.deleted;
      List<AttendData> result =
          await _attendanceService.updateById(sheetId, sheetName, data);

      debugPrint('result = $result');

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

  Future<void> _manualClockIn() async {
    await _manualInput(AttendType.clockIn);
  }

  Future<void> _manualClockOut() async {
    await _manualInput(AttendType.clockOut);
  }

  Future<void> _manualInput(AttendType type) async {
    DateTime? dateTime = await showDialog<DateTime?>(
        context: context,
        builder: (_) {
          return DateTimePickerDialog(
              dateTime: _selectedDate,
              //nameList: _nameList,
              selectedName: _chooseName,
              selectedType: type);
        });

    if (dateTime == null) {
      return;
    }
    try {
      _isLoading = true;
      String sheetId = _attendanceService.getSheetId(dateTime);
      String sheetName = _attendanceService.getSheetName(dateTime);
      String name = _chooseName;
      AttendData data = AttendData(name, type, dateTime);

      List<AttendData> result =
          await _attendanceService.setClock(sheetId, sheetName, data);
      _dataList.clear();
      _dataList.addAll(result);
      _isLoading = false;

      setState(() {
        _updateDataRow();
      });
      await Future.delayed(wait100Milliseconds);
      setState(() {
        _scrollToEnd();
      });
    } catch (e) {
      _isLoading = false;
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(_selectedDate.year - 1),
        lastDate: DateTime(_selectedDate.year + 1));
    if (picked == null) {
      return;
    }

    _selectedDate = picked;

    _dataList.clear();
    setState(() {
      _updateDataRow();
    });

    _getByDateTime(picked);
  }

  Widget _clock(DateTime clock) {
    TextStyle? clockTextStyle = Theme.of(context).textTheme.headlineSmall;
    String clockString = AttendData.dateTimeFormat.format(clock);
    return Center(
      child: Text(clockString, style: clockTextStyle),
    );
  }

  Widget _dateButton(DateTime date, VoidCallback onPressed) {
    final DateFormat dateFormat = DateFormat('yyyy/MM/dd');
    return Center(
        child: ElevatedButton(
      //child: Text(_dateFormat.format(_selectedDate)),
      child: Text(dateFormat.format(date)),
      onPressed: () {
        onPressed();
      },
    ));
  }

  Widget _buttons() {
    TextStyle? buttonTextStyle = TextStyle(
        color: Colors.white,
        fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize);

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Expanded(
          child: SizedBox(
              height: 50,
              child: ElevatedButton(
                  onPressed: _manualClockIn,
                  child: Text('出勤', style: buttonTextStyle)))),
      const SizedBox(width: 10),
      Expanded(
          child: SizedBox(
              height: 50,
              child: ElevatedButton(
                  onPressed: _manualClockOut,
                  child: Text('退勤', style: buttonTextStyle)))),
      const SizedBox(width: 10),
      Expanded(
          child: SizedBox(
              height: 50,
              child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TimecardPage(
                                service: _attendanceService,
                                title: widget.title,
                                name: _chooseName,
                                dateTime: _selectedDate)));
                  },
                  child: Text('タイムカード', style: buttonTextStyle)))),
    ]);
  }

  Widget _nameButtons() {
    TextStyle? choiceTextStyle = Theme.of(context).textTheme.headlineSmall;
    return Column(children: [
      Wrap(
          spacing: 10,
          children:
              // _choiceChipList)]),
              List<ChoiceChip>.generate(_nameList.length, (int index) {
            return ChoiceChip(
              label: Text(_nameList[index], style: choiceTextStyle),
              selectedColor: Colors.yellow,
              selected: _choiceIndex == index,
              onSelected: (selected) {
                _choiceIndex = index;
              },
            );
          }))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: MyAppBar(title: widget.title, version: Constants.version)
            .appBar(context),
        body: SingleChildScrollView(
            child: Padding(
          padding: allPadding,
          child: Center(
              child: Column(children: [
            SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.05,
                child: _clock(_clockDate)),
            SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.05,
                child: _dateButton(_selectedDate, _selectDate)),
            Padding(
                padding: topBottomPadding,
                child: SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: DataTableView(
                        scrollController: _scrollController,
                        columns: _createDataColumnList(),
                        rows: _dataRowList,
                        isLoading: _isLoading))),
            _buttons(),
            Padding(padding: allPadding, child: _nameButtons())
          ])),
        )));
  }
}
