import 'dart:convert';

import 'package:flutter/material.dart';

import 'services/gas_client.dart';
import 'services/attendance_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

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
      'https://script.googleapis.com/v1/scripts/AKfycbwOUlUOHl8HBbZDGdO5MOOBA95Dcv3YKPOBNtg9uRHhpbmYpzX3W0TqFvQikJJ1tBPH:run';

  final String _defaultSheetName = '八木';
  late List<Widget> _textList;

  late GasClient _gasClient;
  late AttendanceService _attendanceService;

  @override
  void initState() {
    super.initState();
    _textList = <Widget>[];
    _gasClient =
        GasClient(clientId, clientSecret, refreshToken, tokenUrl, apiUrl);
    _attendanceService = AttendanceService(_gasClient);
  }

  Future<void> _get() async {
    print('doGet');
    var jsonResult = await _attendanceService.getData();

    setState(() {
      print('response');
      jsonResult.forEach((element) {
        _textList.add(SelectableText(element.toString()));
      });
    });
  }

  Future<void> _clockIn() async {
    var jsonResult = await _attendanceService.clockIn();
    //var jsonResult = await _gasClient.doPost(_defaultSheetName);
    print(jsonResult);
    setState(() {
      _textList.add(SelectableText(json.encode(jsonResult)));
      /*
      jsonResult.forEach((element) {
        if (!element.isNull) {
          _textList.add(SelectableText(element.toString()));
        }
      });
      */
    });
  }

  Future<void> _clockOut() async {
    var jsonResult = await _attendanceService.clockOut();
    //var jsonResult = await _gasClient.doPost(_defaultSheetName);
    print(jsonResult);
    setState(() {
      _textList.add(SelectableText(json.encode(jsonResult)));
      /*
      jsonResult.forEach((element) {
        if (!element.isNull) {
          _textList.add(SelectableText(element.toString()));
        }
      });
      */
    });
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
      body: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: Column(children: [
        SingleChildScrollView(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _textList)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FloatingActionButton(
            onPressed: _get,
            child: const Text('GET'),
          ),
          FloatingActionButton(onPressed: _clockIn, child: const Text('出勤')),
          FloatingActionButton(onPressed: _clockOut, child: const Text('退勤'))
        ]),
      ])),
    );
  }
}
