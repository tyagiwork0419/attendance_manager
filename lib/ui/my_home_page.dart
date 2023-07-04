import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../models/attend_data.dart';
import '../services/gas_client.dart';
import '../services/attendance_service.dart';
import '../application/constants.dart';

import 'components/data_table_view.dart';
import 'components/datetime_picker_dialog.dart';
import 'components/delete_dialog.dart';
import 'components/error_dialog.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final sheetId = '2023年';

  final List<DataRow> _dataRowList = [];

  late GasClient _gasClient;
  late AttendanceService _attendanceService;

  final TextStyle _buttonTextStyle = const TextStyle(fontSize: 15);

  final List<String> _nameList = <String>[
    'test',
    '八木',
    '大滝',
    '山本',
    '広瀬',
    '坂下',
    '西本'
  ];

  final EdgeInsets topBottomPadding = const EdgeInsets.fromLTRB(0, 10, 0, 10);
  final EdgeInsets allPadding = const EdgeInsets.all(10);

  final ScrollController _scrollController = ScrollController();
  final Duration wait100Milliseconds = const Duration(milliseconds: 100);

  String _clockString = '';
  late DateTime _selectedDate;
  late DateFormat _clockFormat; // = DateFormat('yyyy/MM/dd  HH:mm:ss E');
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');

  final List<AttendData> _dataList = [];

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

    initializeDateFormatting('ja');

    _clockFormat = DateFormat('yyyy/MM/dd  HH:mm:ss E', 'ja');

    DateTime now = DateTime.now();
    _clockString = _clockFormat.format(now);
    _selectedDate = now;

    Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
      DateTime now = DateTime.now();

      _clockString = _clockFormat.format(now);
      setState(() {});
    });

    _get(now);
  }

  DataRow _getDataRowByAttendData(AttendData data) {
    String name = data.name;
    String time = data.timeStr;
    String type = data.type.toStr;
    Color color;
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
          DataCell(Text(name)),
          DataCell(Text(time)),
          DataCell(Text(type)),
          DataCell(IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              print('presseed');
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

  String _getSheetName(DateTime dateTime) {
    return '${dateTime.month}月';
  }

  void _updateDataRow() {
    _dataRowList.clear();
    for (int i = 0; i < _dataList.length; ++i) {
      _dataRowList.add(_getDataRowByAttendData(_dataList[i]));
    }
  }

  void _scrollToEnd() {
    _scrollController.animateTo(_scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100), curve: Curves.ease);
  }

  Future<void> _get(DateTime dateTime) async {
    String sheetName = _getSheetName(dateTime);

    try {
      List<AttendData> result =
          await _attendanceService.getData(sheetId, sheetName, dateTime);
      _dataList.clear();
      _dataList.addAll(result);
      setState(() {
        _updateDataRow();
      });
      await Future.delayed(wait100Milliseconds);
      setState(() {
        _scrollToEnd();
      });
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String error) {
    print(error);
    showDialog<void>(
        context: context,
        builder: (_) => ErrorDialog(title: '通信エラー', content: error));
  }

  Future<void> _clockIn() async {
    try {
      List<AttendData> result = await _setClock(AttendType.clockIn);

      _dataList.clear();
      _dataList.addAll(result);

      setState(() {
        _updateDataRow();
      });
      await Future.delayed(wait100Milliseconds);
      setState(() {
        _scrollToEnd();
      });
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _clockOut() async {
    try {
      List<AttendData> result = await _setClock(AttendType.clockOut);
      _dataList.clear();
      _dataList.addAll(result);

      setState(() {
        _updateDataRow();
      });
      await Future.delayed(wait100Milliseconds);
      setState(() {
        _scrollToEnd();
      });
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<List<AttendData>> _setClock(AttendType type) async {
    DateTime now = DateTime.now();
    String sheetName = _getSheetName(now);
    //String name = _dropdownValue;
    String name = _chooseName;
    AttendData data = AttendData(name, type, now);
    List<AttendData> result =
        await _attendanceService.setClock(sheetId, sheetName, data);

    return result;
  }

  Future<void> _deleteRow(AttendData data) async {
    try {
      print('delete row');
      String sheetName = _getSheetName(data.time);
      List<AttendData> result = await _attendanceService.updateStatusById(
          sheetId, sheetName, data.id, 'deleted');

      print('result = $result');

      _dataList.clear();
      _dataList.addAll(result);

      setState(() {
        _updateDataRow();
      });
    } catch (e) {
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
    try {
      //await _attendanceService.setClock(sheetId, sheetName, data);
      DateTime? dateTime = await showDialog<DateTime?>(
          context: context,
          builder: (_) {
            return const DateTimePickerDialog();
          });

      if (dateTime != null) {
        String sheetName = _getSheetName(dateTime);
        //String name = _dropdownValue;
        String name = _chooseName;
        AttendData data = AttendData(name, type, dateTime);

        List<AttendData> result =
            await _attendanceService.setClock(sheetId, sheetName, data);
        _dataList.clear();
        _dataList.addAll(result);

        setState(() {
          _updateDataRow();
        });
        await Future.delayed(wait100Milliseconds);
        setState(() {
          _scrollToEnd();
        });
      }
    } catch (e) {
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

    _get(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
          actions: const [
            Padding(
                padding: EdgeInsets.only(right: 30),
                child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('version: ${Constants.version}')))
          ],
        ),
        body: Padding(
            padding: allPadding,
            child: SingleChildScrollView(
              child: Center(
                  // Center is a layout widget. It takes a single child and positions it
                  // in the middle of the parent.
                  child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.05,
                  child: Center(
                    child: Text(_clockString,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.05,
                    child: Center(
                        child: ElevatedButton(
                      child: Text(_dateFormat.format(_selectedDate)),
                      onPressed: () {
                        _selectDate();
                      },
                    ))),
                Padding(
                    padding: topBottomPadding,
                    child: SizedBox(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: DataTableView(
                          scrollController: _scrollController,
                          dataRowList: _dataRowList,
                        ))),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  /*
                  Expanded(
                      child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _get,
                            child: Text('GET', style: _buttonTextStyle),
                          ))),
                  const SizedBox(width: 10),
                  */
                  Expanded(
                      child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                              onPressed: _clockIn,
                              child: Text('出勤', style: _buttonTextStyle)))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                              onPressed: _clockOut,
                              child: Text('退勤', style: _buttonTextStyle)))),
                ]),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Expanded(
                      child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                              onPressed: _manualClockIn,
                              child: Text('手動出勤', style: _buttonTextStyle)))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                              onPressed: _manualClockOut,
                              child: Text('手動退勤', style: _buttonTextStyle)))),
                ]),
                Padding(
                  padding: allPadding,
                  child: Column(children: [
                    Wrap(
                        spacing: 10,
                        children:
                            // _choiceChipList)]),
                            List<ChoiceChip>.generate(_nameList.length,
                                (int index) {
                          return ChoiceChip(
                            label: Text(_nameList[index],
                                style: const TextStyle(fontSize: 20)),
                            selectedColor: Colors.yellow,
                            selected: _choiceIndex == index,
                            onSelected: (selected) {
                              _choiceIndex = index;
                            },
                          );
                        }))
                  ]),

                  /*
                    child: DropdownButton<String>(
                        value: _dropdownValue,
                        items: nameList
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                              value: value, child: Text(value));
                        }).toList(),
                        onChanged: (String? value) {
                          setState(() {
                            _dropdownValue = value!;
                          });
                        })*/
                )
              ])),
            )));
  }
}
