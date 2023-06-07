import 'gas_client.dart';
import '../models/attend_data.dart';

class AttendanceService {
  final GasClient _gasClient;
  final _sheetName = 'シート1';

  AttendanceService(this._gasClient);

  Future<dynamic> clockIn() async {
    print('clock in');
    String name = '八木';
    DateTime now = DateTime.now();

    AttendData attendData = AttendData(1, name, now, AttendType.clockIn, now);
    Map<String, String> jsonObj = attendData.toJson();
    Map<String, Object> postData = {
      'sheet': _sheetName,
      'postData': jsonObj,
    };
    print(postData);

    var jsonResult = await _gasClient.post(postData);
    return jsonResult;
  }

  Future<dynamic> clockOut() async {
    print('clock out');
    String name = '八木';
    DateTime now = DateTime.now();

    AttendData attendData = AttendData(1, name, now, AttendType.clockOut, now);
    Map<String, String> jsonObj = attendData.toJson();
    Map<String, Object> postData = {
      'sheet': _sheetName,
      'postData': jsonObj,
    };
    print(postData);

    var jsonResult = await _gasClient.post(postData);
    return jsonResult;
  }

  Future<dynamic> getData() async {
    var jsonResult = await _gasClient.get(_sheetName);
    return jsonResult;
  }
}
