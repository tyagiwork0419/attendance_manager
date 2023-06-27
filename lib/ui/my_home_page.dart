import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attend_data.dart';
import '../services/gas_client.dart';
import '../services/attendance_service.dart';
import '../application/constants.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final sheetId = '2023年';

  late List<DataRow> _dataRowList;

  late GasClient _gasClient;
  late AttendanceService _attendanceService;

  final TextStyle _buttonTextStyle = const TextStyle(fontSize: 20);

  final List<String> nameList = <String>['八木', '大滝', '山本', '広瀬', '坂下', '西本'];
  late String _dropdownValue;
  late TimeOfDay selectedTime;

  final EdgeInsets topBottomPadding = const EdgeInsets.fromLTRB(0, 10, 0, 10);
  final EdgeInsets allPadding = const EdgeInsets.all(10);

  final ScrollController _scrollController = ScrollController();
  final Duration wait100Milliseconds = const Duration(milliseconds: 100);

  String _clockString = '';
  final DateFormat _clockFormat = DateFormat('yyyy/MM/dd  HH:mm:ss');

  List<AttendData> _dataList = [];

  @override
  void initState() {
    super.initState();
    _dropdownValue = nameList.first;
    selectedTime = TimeOfDay.now();
    _dataRowList = <DataRow>[];
    _gasClient = GasClient(Constants.clientId, Constants.clientSecret,
        Constants.refreshToken, Constants.tokenUrl, Constants.apiUrl);
    _attendanceService = AttendanceService(_gasClient);
    DateTime now = DateTime.now();
    _clockString = _clockFormat.format(now);

    Timer(const Duration(milliseconds: 100), () {
      DateTime now = DateTime.now();

      _clockString = _clockFormat.format(now);
    });

    _get();
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
            onPressed: () {
              print('presseed');
            },
          )),
        ]);

    return dataRow;
  }

  String _getSheetName(DateTime dateTime) {
    return '${dateTime.month}月';
  }

  void _addDataRow(List<AttendData> result) {
    for (int i = 0; i < result.length; ++i) {
      _dataRowList.add(_getDataRowByAttendData(result[i]));
    }
  }

  void _scrollToEnd() {
    _scrollController.animateTo(_scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100), curve: Curves.ease);
  }

  Future<void> _get() async {
    String sheetName = _getSheetName(DateTime.now());
    List<AttendData> result =
        await _attendanceService.getData(sheetId, sheetName);
    _dataRowList.clear();
    setState(() {
      _addDataRow(result);
    });
    await Future.delayed(wait100Milliseconds);
    setState(() {
      _scrollToEnd();
    });
  }

  Future<void> _clockIn() async {
    List<AttendData> result = await _setClock(AttendType.clockIn);

    setState(() {
      _addDataRow(result);
    });
    await Future.delayed(wait100Milliseconds);
    setState(() {
      _scrollToEnd();
    });
  }

  Future<void> _clockOut() async {
    List<AttendData> result = await _setClock(AttendType.clockOut);

    setState(() {
      _addDataRow(result);
    });
    await Future.delayed(wait100Milliseconds);
    setState(() {
      _scrollToEnd();
    });
  }

  Future<List<AttendData>> _setClock(AttendType type) async {
    DateTime now = DateTime.now();
    String sheetName = _getSheetName(now);
    String name = _dropdownValue;
    AttendData data = AttendData(name, type, now);
    List<AttendData> result =
        await _attendanceService.setClock(sheetId, sheetName, data);

    return result;
  }

  Future<void> _deleteRow(AttendData data) async {
    String sheetName = _getSheetName(data.time);
    List<AttendData> result = await _attendanceService.updateStatusById(
        sheetId, sheetName, data.id, 'deleted');
    setState(() {
      //  _dataRowList.removeWhere((element) => element.)
    });
  }

  Future<void> _manualClockIn() async {
    await _manualInput(AttendType.clockIn);
  }

  Future<void> _manualClockOut() async {
    await _manualInput(AttendType.clockOut);
  }

  Future<void> _manualInput(AttendType type) async {
    final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: selectedTime,
        initialEntryMode: TimePickerEntryMode.dial);

    if (picked != null) {
      DateTime now = DateTime.now();
      DateTime time =
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      String sheetName = _getSheetName(now);
      String name = _dropdownValue;
      AttendData data = AttendData(name, type, time);

      await _attendanceService.setClock(sheetId, sheetName, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
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
                          style: const TextStyle(fontSize: 20))),
                ),
                Padding(
                    padding: topBottomPadding,
                    child: SizedBox(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Container(
                            decoration:
                                BoxDecoration(border: Border.all(width: 1)),
                            child: SingleChildScrollView(
                                controller: _scrollController,
                                child: DataTable(
                                    headingRowColor:
                                        MaterialStateColor.resolveWith(
                                            (states) => const Color.fromARGB(
                                                255, 218, 218, 218)),
                                    columns: const [
                                      const DataColumn(label: Text('名前')),
                                      const DataColumn(label: Text('時刻')),
                                      const DataColumn(label: Text('種類')),
                                      const DataColumn(label: Text('削除')),
                                      /*
                                      DataColumn(
                                          label: Container(
                                              width: 50, child: Text('修正'))),
                                              */
                                    ],
                                    rows: _dataRowList))))),
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
                        }))
              ])),
            )));
  }
}
