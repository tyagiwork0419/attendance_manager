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
