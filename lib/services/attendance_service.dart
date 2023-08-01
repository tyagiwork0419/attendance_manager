import 'dart:convert';
import 'package:flutter/cupertino.dart';

import 'gas_client.dart';
import '../models/attend_data.dart';

class AttendanceService {
  final GasClient _gasClient;

  //String accessToken = '';

  AttendanceService(this._gasClient);

  String getSheetId(DateTime dateTime) {
    return '${dateTime.year}年';
  }

  String getSheetName(DateTime dateTime) {
    return '${dateTime.month}月';
  }

  Future<List<AttendData>> setClock(
      String fileName, String sheetName, AttendData data) async {
    Map<String, dynamic> jsonObj = data.toJson();
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'postData': jsonObj,
    };
    debugPrint(parameters.toString());

    var jsonResult = await _gasClient.post('insertRows', parameters);
    var result = _parseFromJson(jsonResult);
    return result;
  }

  Future<List<AttendData>> getByDateTime(
      String fileName, String sheetName, DateTime dateTime) async {
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'dateTime': AttendData.dateTimeFormat.format(dateTime)
    };

    var jsonResult = await _gasClient.post('selectByDate', parameters);

    var result = _parseFromJson(jsonResult);
    return result;
  }

  Future<List<AttendData>> getByName(
      String fileName, String sheetName, String name) async {
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'name': name,
    };

    var jsonResult = await _gasClient.post('selectByName', parameters);

    var result = _parseFromJson(jsonResult);

    result.sort((a, b) {
      return a.dateTime.compareTo(b.dateTime);
    });
    return result;
  }

  List<AttendData> _parseFromJson(String jsonResult) {
    List<dynamic> jsonObj = json.decode(jsonResult);

    List<AttendData> result = [];

    for (int i = 0; i < jsonObj.length; ++i) {
      var data = jsonObj[i];
      var attendData = AttendData.fromJson(data);
      result.add(attendData);
    }
    return result;
  }

  Future<List<AttendData>> updateById(
      String fileName, String sheetName, AttendData data) async {
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'postData': data.toJson()
    };
    debugPrint(parameters.toString());

    var jsonResult = await _gasClient.post('updateById', parameters);
    var result = _parseFromJson(jsonResult);
    return result;
  }

  Future<void> getEvents() async {
    Map<String, Object> parameters = {};

    var jsonResult = await _gasClient.post(
      'getEvents',
      parameters,
    );

    debugPrint('result = $jsonResult');
  }
}
