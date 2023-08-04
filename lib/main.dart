import 'package:attendance_manager/services/attendance_service.dart';
import 'package:attendance_manager/services/gas_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
//import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'application/constants.dart';
import 'ui/pages/my_home_page.dart';

void main() {
  initializeDateFormatting('ja');

  //runApp(const TestApp());

  GasClient gasClient = GasClient(Constants.clientId, Constants.clientSecret,
      Constants.refreshToken, Constants.tokenUrl, Constants.apiUrl);
  AttendanceService attendanceService = AttendanceService(gasClient);

  runApp(MyApp(attendanceService: attendanceService));
}

class MyApp extends StatelessWidget {
  final AttendanceService attendanceService;

  MyApp({super.key, required this.attendanceService}) {
    attendanceService.getEvents();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: '勤怠管理',
        theme: ThemeData(
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          primarySwatch: Colors.blue,
        ),
        /*
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ja'),
        ],
        */
        home: MyHomePage(title: '勤怠管理', attendanceService: attendanceService));
  }
}
