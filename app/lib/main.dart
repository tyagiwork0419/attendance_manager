import 'package:attendance_manager/services/attendance_service.dart';
import 'package:attendance_manager/services/device_session.dart';
import 'package:attendance_manager/services/gas_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'application/constants.dart';
import 'ui/pages/device_registration_page.dart';
import 'ui/pages/my_home_page.dart';

void main() {
  //initializeDateFormatting('ja');

  //runApp(const TestApp());

  DeviceSession deviceSession = DeviceSession();
  deviceSession.load();

  GasClient gasClient = GasClient(Constants.webAppUrl, deviceSession);
  AttendanceService attendanceService = AttendanceService(gasClient);

  runApp(MyApp(attendanceService: attendanceService));
}

class MyApp extends StatefulWidget {
  final AttendanceService attendanceService;

  const MyApp({super.key, required this.attendanceService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDeviceRegistered;

  @override
  void initState() {
    super.initState();
    _isDeviceRegistered = widget.attendanceService.isDeviceRegistered;
    if (_isDeviceRegistered) {
      _startSession();
    }
  }

  /// 祝日カレンダーの先読み。失敗しても打刻はできるので画面は止めない。
  void _startSession() {
    widget.attendanceService.getEvents().catchError((Object e) {
      debugPrint('getEvents failed: $e');
    });
  }

  void _onRegistered() {
    setState(() {
      _isDeviceRegistered = true;
    });
    _startSession();
  }

  /// 端末が失効していた場合に登録画面へ戻す。
  void _onDeviceRevoked() {
    setState(() {
      _isDeviceRegistered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: '勤怠管理',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ja'),
        ],
        locale: const Locale('ja'),
        home: _isDeviceRegistered
            ? MyHomePage(
                title: '勤怠管理',
                attendanceService: widget.attendanceService,
                onDeviceRevoked: _onDeviceRevoked)
            : DeviceRegistrationPage(
                attendanceService: widget.attendanceService,
                onRegistered: _onRegistered));
  }
}
