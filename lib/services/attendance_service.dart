import 'gas_client.dart';
import '../models/attend_data.dart';

class AttendanceService {
  final GasClient _gasClient;

  AttendanceService(this._gasClient);

  Future<dynamic> clockIn(String fileName, String sheetName, DateTime time, AttendType type) async {
    print('clock in');

    AttendData attendData = AttendData(1, sheetName, type, time, Status.normal);
    Map<String, String> jsonObj = attendData.toJson();
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
      'postData': jsonObj,
    };
    print(parameters);

    var jsonResult = await _gasClient.post(parameters);
    return jsonResult;
  }

  Future<dynamic> getData(String fileName, String sheetName) async {
    Map<String, Object> parameters = {
      'fileName': fileName,
      'sheetName': sheetName,
    };
    var jsonResult = await _gasClient.get(parameters);

    return jsonResult;
  }
}
