import 'dart:convert';
import 'package:http/http.dart' as http;

class GasClient {
  late String _clientId;
  late String _clientSecret;
  late String _refreshToken;
  late String _tokenUrl;
  late String _apiUrl;

  GasClient(this._clientId, this._clientSecret, this._refreshToken,
      this._tokenUrl, this._apiUrl);

  Future<dynamic> _getAccessToken() async {
    Map<String, String> headers = {'content-type': 'application/json'};
    String body = json.encode({
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'refresh_token': _refreshToken,
      'grant_type': 'refresh_token',
    });

    http.Response response =
        await http.post(Uri.parse(_tokenUrl), headers: headers, body: body);
    var data = jsonDecode(response.body);
    var accessToken = data['access_token'];
    return accessToken;
  }

  Future<dynamic> get(String sheetName) async {
    var accessToken = await _getAccessToken();

    Uri uri = Uri.parse(_apiUrl);

    final body = json.encode({
      'function': 'doGet',
      'parameters': {
        'sheet': sheetName,
      }
    });

    Map<String, String> headers = {
      'Authorization': 'Bearer $accessToken',
    };

    http.Response response = await http.post(uri, headers: headers, body: body);
    var data = json.decode(response.body);
    print(data);
    String result = data['response']['result'];
    var jsonResult = json.decode(result);
    return jsonResult;
  }

  Future<dynamic> post(Object postData) async {
    Uri uri = Uri.parse(_apiUrl);
    var accessToken = await _getAccessToken();

/*
    String name = '八木';
    DateTime now = DateTime.now();
    DateFormat outputFormat = DateFormat('yyyy/MM/dd hh:mm:ss');
    String time = outputFormat.format(now);
    print(time);

    AttendData attendData = AttendData(1, name, now, AttendType.clockIn, now);
    Map<String, String> jsonObj = attendData.toJson();
    */

    final body = json.encode({
      'function': 'doPost',
      'parameters': postData,
      //'parameters': {'sheet': sheetName, 'postData': jsonObj}
    });

    print(body);

    Map<String, String> headers = {
      'Authorization': 'Bearer $accessToken',
    };

    http.Response response = await http.post(uri, headers: headers, body: body);
    Map data = json.decode(response.body);
    print(data);
    var result = data['response'];
    return result;
  }
}
