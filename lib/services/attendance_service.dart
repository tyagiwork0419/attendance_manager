import 'dart:convert';
import 'gas_client.dart';
import '../models/attend_data.dart';

class AttendanceService {
  final GasClient _gasClient;

  String accessToken = '';

  AttendanceService(this._gasClient);

  Future<List<AttendData>> setClock(
      String fileName, String sheetName, AttendData data) async {
    //AttendData attendData = AttendData(0, name, type, time, Status.normal);
    Map<String, dynamic> jsonObj = data.toJson();
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'postData': jsonObj,
    };
    print(parameters);

    var jsonResult =
        await _gasClient.post('insertRows', accessToken, parameters);
    print('jsonResult = $jsonResult');
    var result = _parseFromJson(jsonResult);
    return result;
  }

  //Future<List<AttendData>> getData(String fileName, String sheetName) async {
  Future<List<AttendData>> getData(String fileName, String sheetName) async {
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
    };
    //accessToken = await _gasClient.getAccessToken();
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

  Future<List<AttendData>> updateStatusById(
      String fileName, String sheetName, int id, String status) async {
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'postData': {'id': id, 'status': status},
    };
    print(parameters);

    var jsonResult =
        await _gasClient.post('updateStatusById', accessToken, parameters);
    print('jsonResult = $jsonResult');
    var result = _parseFromJson(jsonResult);
    return result;
  }
}
