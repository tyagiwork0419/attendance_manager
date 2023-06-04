import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
      //'https://script.googleapis.com/v1/scripts/AKfycbzTA-MiqzQ9DIpfRV46cjXVTHcALM8OQRfTqdpr8NjwBADEaTlwunYDKO2N9Qj0_OQI:run';
      'https://script.googleapis.com/v1/scripts/AKfycbwOUlUOHl8HBbZDGdO5MOOBA95Dcv3YKPOBNtg9uRHhpbmYpzX3W0TqFvQikJJ1tBPH:run';
  late List<Widget> _textList;

  @override
  void initState() {
    super.initState();
    _textList = <Widget>[];
  }

  Future<void> _doGet() async {
    print('doGet');

    Uri uri = Uri.parse(apiUrl);
    var accessToken = await _getAccessToken();

    final body = json.encode({
      'function': 'doGet',
      'parameters': {
        'sheet': 'シート1',
      }
    });

    Map<String, String> headers = {
      //'Access-Control-Allow-Origin': '*',
      //'Content-Type': 'application/x-www-form-urlencoded',
      //'crossDomain': 'true'
      //'Access-Control-Allow-Methods': 'POST, GET'
      'Authorization': 'Bearer $accessToken',
    };

    http.Response response = await http.post(uri, headers: headers, body: body);
    var data = json.decode(response.body);
    print(data);
    String result = data['response']['result'];
    var jsonResult = json.decode(result);
    print(jsonResult);

    setState(() {
      print('response');
      jsonResult.forEach((element) {
        _textList.add(SelectableText(element.toString()));
      });
    });
  }

  Future<void> _doPost() async {
    Uri uri = Uri.parse(apiUrl);
    var accessToken = await _getAccessToken();

    final body = json.encode({
      'function': 'doPost',
      'parameters': {
        'sheet': 'シート1',
        'postData': {
          'task': '1',
          'status': '2',
          'etc': '3',
        }
      }
    });

    Map<String, String> headers = {
      'Authorization': 'Bearer $accessToken',
    };

    http.Response response = await http.post(uri, headers: headers, body: body);
    Map data = json.decode(response.body);
    print(data);
    try {
      String result = data['response']['result'];
      var jsonResult = json.decode(result);
      print(jsonResult);
      setState(() {
        jsonResult.forEach((element) {
          if (!element.isNull) {
            _textList.add(SelectableText(element.toString()));
          }
        });
      });
    } catch (e) {
      print(e);
      setState(() {
        _textList.add(SelectableText(e.toString()));
      });
    }
  }

  Future<dynamic> _getAccessToken() async {
    Map<String, String> headers = {'content-type': 'application/json'};
    String body = json.encode({
      'client_id': clientId,
      'client_secret': clientSecret,
      'refresh_token': refreshToken,
      'grant_type': 'refresh_token',
    });

    http.Response response =
        await http.post(Uri.parse(tokenUrl), headers: headers, body: body);
    var data = jsonDecode(response.body);
    var accessToken = data['access_token'];
    return accessToken;
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
            onPressed: _doGet,
            child: const Text('GET'),
          ),
          FloatingActionButton(onPressed: _doPost, child: const Text('POST'))
        ]),
      ])),
    );
  }
}
