import 'dart:convert';
import 'package:flutter/cupertino.dart';

import 'gas_client.dart';
import '../models/attend_data.dart';

class AttendanceService {
  final GasClient _gasClient;

  String accessToken = '';

  AttendanceService(this._gasClient);

  Future<List<AttendData>> setClock(
      String fileName, String sheetName, AttendData data) async {
    Map<String, dynamic> jsonObj = data.toJson();
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'postData': jsonObj,
    };
    debugPrint(parameters.toString());

    var jsonResult =
        await _gasClient.post('insertRows', accessToken, parameters);
    var result = _parseFromJson(jsonResult);
    return result;
  }

  Future<List<AttendData>> getData(
      String fileName, String sheetName, DateTime dateTime) async {
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'dateTime': AttendData.dateTimeFormat.format(dateTime)
    };

    var jsonResult =
        await _gasClient.post('selectByDate', accessToken, parameters);

    var result = _parseFromJson(jsonResult);
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

    var jsonResult =
        await _gasClient.post('updateById', accessToken, parameters);
    var result = _parseFromJson(jsonResult);
    return result;
  }
}
