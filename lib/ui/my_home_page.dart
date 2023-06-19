import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/attend_data.dart';
import '../services/gas_client.dart';
import '../services/attendance_service.dart';

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
  final String scope =
      'https://www.googleapis.com/auth/spreadsheets.currentonly';
  final String tokenUrl = 'https://oauth2.googleapis.com/token';
  final String clientId =
      '899530760082-skgo3k4sjv5la566sa598icfgdsusmgt.apps.googleusercontent.com';
  final String clientSecret = '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';
  final String refreshToken =
      '1//04XRNXaZDiVi0CgYIARAAGAQSNwF-L9Ir9VhSIX3NuGEv6q2cbtfaYmwbPapfd815IMEjnfgRBMdMm4HaACuuvbVAL2Fui8ftT34';
  final String apiUrl =
      'https://script.googleapis.com/v1/scripts/AKfycby1gGxnJF3V2GwXxZUPRg8EzvBkMKHJD5BUgl-ox1f1bmTHWhqiDTeZ10OkQh-a-ewW:run';

  late List<Widget> _textList;

  late GasClient _gasClient;
  late AttendanceService _attendanceService;

  final TextStyle _buttonTextStyle = const TextStyle(fontSize: 30);

  final List<String> nameList = <String>['八木', '大滝'];
  late String dropdownValue;
  late TimeOfDay selectedTime;

  @override
  void initState() {
    super.initState();
    dropdownValue = nameList.first;
    selectedTime = TimeOfDay.now();
    _textList = <Widget>[];
    _gasClient =
        GasClient(clientId, clientSecret, refreshToken, tokenUrl, apiUrl);
    _attendanceService = AttendanceService(_gasClient);
  }

  Future<void> _get() async {
    print('doGet');
    var jsonResult = await _attendanceService.getData(dropdownValue);

    setState(() {
      print('response');
      jsonResult.forEach((element) {
        _textList.add(SelectableText(element.toString()));
      });
    });
  }

  Future<void> _clockIn() async {
    var jsonResult = await _attendanceService.clockIn(
        dropdownValue, DateTime.now(), AttendType.clockIn);
    //var jsonResult = await _gasClient.doPost(_defaultSheetName);
    print(jsonResult);
    setState(() {
      _textList.add(SelectableText(json.encode(jsonResult)));
    });
  }

  Future<void> _clockOut() async {
    var jsonResult = await _attendanceService.clockIn(
        dropdownValue, DateTime.now(), AttendType.clockOut);
    print(jsonResult);
    setState(() {
      _textList.add(SelectableText(json.encode(jsonResult)));
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

      var jsonResult =
          await _attendanceService.clockIn(dropdownValue, time, type);
      //var jsonResult = await _gasClient.doPost(_defaultSheetName);
      print(jsonResult);
      setState(() {
        _textList.add(SelectableText(json.encode(jsonResult)));
      });
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
        ),
        body: SingleChildScrollView(
          child: Center(
              // Center is a layout widget. It takes a single child and positions it
              // in the middle of the parent.
              child: Column(children: [
            Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(width: 1)),
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _textList)),
                    ))),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Expanded(
                  child: SizedBox(
                      height: 100,
                      child: ElevatedButton(
                        onPressed: _get,
                        child: Text('GET', style: _buttonTextStyle),
                      ))),
              const SizedBox(width: 10),
              Expanded(
                  child: SizedBox(
                      height: 100,
                      child: ElevatedButton(
                          onPressed: _clockIn,
                          child: Text('出勤', style: _buttonTextStyle)))),
              const SizedBox(width: 10),
              Expanded(
                  child: SizedBox(
                      height: 100,
                      child: ElevatedButton(
                          onPressed: _clockOut,
                          child: Text('退勤', style: _buttonTextStyle)))),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Expanded(
                  child: SizedBox(
                      width: 200,
                      height: 100,
                      child: ElevatedButton(
                          onPressed: _manualClockIn,
                          child: Text('手動出勤', style: _buttonTextStyle)))),
              const SizedBox(width: 10),
              Expanded(
                  child: SizedBox(
                      height: 100,
                      child: ElevatedButton(
                          onPressed: _manualClockOut,
                          child: Text('手動退勤', style: _buttonTextStyle)))),
            ]),
            Padding(
                padding: const EdgeInsets.all(10),
                child: DropdownButton<String>(
                    value: dropdownValue,
                    items:
                        nameList.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                          value: value, child: Text(value));
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        dropdownValue = value!;
                      });
                    }))
          ])),
        ));
  }
}
