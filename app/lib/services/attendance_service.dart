import 'dart:convert';
import 'package:flutter/cupertino.dart';

import '../models/calendar.dart';
import '../models/monthly_timecard.dart';
import 'gas_client.dart';
import '../models/attend_data.dart';

class AttendanceService {
  final GasClient _gasClient;

  final Calendar _calendar = Calendar();

  bool initialized = false;

  //String accessToken = '';

  AttendanceService(this._gasClient);

  bool get isAuthenticated => _gasClient.isAuthenticated;

  bool get isDeviceRegistered => _gasClient.isDeviceRegistered;

  /// この端末の名義。共有端末なら null。
  String? get deviceUser => _gasClient.deviceUser;

  /// この端末を登録する。パスワードが違う場合は false を返す。
  Future<bool> registerDevice(
    String name,
    String password, {
    required String label,
    required bool shared,
  }) {
    return _gasClient.registerDevice(name, password,
        label: label, shared: shared);
  }

  void clearDevice() {
    _gasClient.clearDevice();
  }

  /// この端末を共有端末にするか、特定の人の端末にするかを切り替える。
  /// パスワードが違う場合は false を返す。
  Future<bool> updateDeviceOwner(
    String name,
    String password, {
    required bool shared,
  }) {
    return _gasClient.updateDeviceOwner(name, password, shared: shared);
  }

  /// パスワードを変更する。失敗時は [GasException] を投げる。
  Future<void> changePassword(
    String name, {
    required String currentPassword,
    required String newPassword,
  }) {
    return _gasClient.changePassword(name,
        currentPassword: currentPassword, newPassword: newPassword);
  }

  /// ログイン画面に表示する名前の一覧。GAS 側から取得する。
  Future<List<String>> getUserNames() {
    return _gasClient.getUserNames();
  }

  /// パスワード照合は GAS 側で行う。違う場合は false を返す。
  Future<bool> login(String name, String password) {
    return _gasClient.login(name, password);
  }

  void logout() {
    _gasClient.clearSession();
  }

  String getSheetId(DateTime dateTime) {
    return '${dateTime.year}年';
  }

  String getSheetName(DateTime dateTime) {
    return '${dateTime.month}月';
  }

  Future<List<AttendData>> setAttendData(
      String fileName, String sheetName, AttendData data) async {
    debugPrint('setClock');
    Map<String, dynamic> jsonObj = data.toJson();
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'postData': jsonObj,
    };
    debugPrint(parameters.toString());

    var jsonResult = await _gasClient.post('insertRows', parameters);
    List<dynamic> jsonObject = json.decode(jsonResult);
    var result = _parseAttendDataFromJson(jsonObject);
    return result;
  }

  Future<List<AttendData>> getByDateTime(
      String fileName, String sheetName, DateTime dateTime) async {
    debugPrint('getByDateTime');
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'dateTime': AttendData.dateTimeFormat.format(dateTime)
    };

    var jsonResult = await _gasClient.post('selectByDate', parameters);
    List<dynamic> jsonObj = json.decode(jsonResult);

    var result = _parseAttendDataFromJson(jsonObj);
    return result;
  }

  Future<List<AttendData>> getByName(
      String fileName, String sheetName, String name) async {
    debugPrint('getByName');
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'name': name,
    };

    var jsonResult = await _gasClient.post('selectByName', parameters);
    List<dynamic> jsonObj = json.decode(jsonResult);

    var result = _parseAttendDataFromJson(jsonObj);

    result.sort((a, b) {
      return a.dateTime.compareTo(b.dateTime);
    });
    return result;
  }

  Future<List<AttendData>> updateById(
      String fileName, String sheetName, AttendData data) async {
    debugPrint('updateById');
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'postData': data.toJson()
    };
    debugPrint(parameters.toString());

    var jsonResult = await _gasClient.post('updateById', parameters);
    List<dynamic> jsonObj = json.decode(jsonResult);
    var result = _parseAttendDataFromJson(jsonObj);
    return result;
  }

  Future<void> getEvents() async {
    debugPrint('getEvents');
    Map<String, Object> parameters = {};

    var jsonResult = await _gasClient.post(
      'getEvents',
      parameters,
    );

    debugPrint('result = $jsonResult');

    List<dynamic> jsonObj = json.decode(jsonResult);

    var events = _parseCalendarEventFromJson(jsonObj);

    _calendar.setEvents(events);
    initialized = true;
  }

  MonthlyTimecard createMonthlyTimecard(
      String name, int year, int month, List<AttendData> dataList) {
    debugPrint('createMonthlyTimecard');
    MonthlyTimecard monthlyTimecard =
        MonthlyTimecard.create(name, year, month, dataList, _calendar);
    //MonthlyTimecard monthlyTimecard = dataMap[month]!;
    return monthlyTimecard;
  }

  List<AttendData> _parseAttendDataFromJson(List<dynamic> jsonObj) {
    //List<dynamic> jsonObj = json.decode(jsonResult);

    List<AttendData> result = [];

    for (int i = 0; i < jsonObj.length; ++i) {
      var data = jsonObj[i];
      var attendData = AttendData.fromJson(data);
      result.add(attendData);
    }
    return result;
  }

  List<CalendarEvent> _parseCalendarEventFromJson(List<dynamic> events) {
    List<CalendarEvent> result = [];
    for (int i = 0; i < events.length; ++i) {
      Map<String, dynamic> event = events[i];
      CalendarEvent calendarEvent = CalendarEvent.fromJson(event);
      result.add(calendarEvent);
    }

    return result;
  }
}
