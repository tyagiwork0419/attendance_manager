import 'gas_client.dart';
import '../models/attend_data.dart';

class AttendanceService {
  final GasClient _gasClient;
  //final _sheetName = 'シート1';

  AttendanceService(this._gasClient);

  Future<dynamic> clockIn(String name, DateTime time, AttendType type) async {
    print('clock in');
    DateTime now = DateTime.now();

    AttendData attendData = AttendData(1, name, time, type, now);
    Map<String, String> jsonObj = attendData.toJson();
    Map<String, Object> parameters = {
      'sheet': name,
      'postData': jsonObj,
    };
    print(parameters);

    var jsonResult = await _gasClient.post(parameters);
    return jsonResult;
  }

  Future<dynamic> getData(String name) async {
    Map<String, Object> parameters = {'sheet': name};
    var jsonResult = await _gasClient.get(parameters);
    return jsonResult;
  }
}
