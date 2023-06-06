import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';

import './attend_data.dart';

class GasClient {
  late String clientId;
  late String clientSecret;
  late String refreshToken;
  late String tokenUrl;
  late String apiUrl;

  GasClient(this.clientId, this.clientSecret, this.refreshToken, this.tokenUrl,
      this.apiUrl);

  Future<dynamic> _getAccessToken() async {
    Map<String, String> headers = {'content-type': 'application/json'};
    String body = json.encode({
      'client_id': clientId,
      'client_secret': clientSecret,
      'refresh_token': refreshToken,
      'grant_type': 'refresh_token',
    });

    http.Response response =
        await http.post(Uri.parse(tokenUrl), headers: headers, body: body);
    var data = jsonDecode(response.body);
    var accessToken = data['access_token'];
    return accessToken;
  }

  Future<dynamic> doGet() async {
    var accessToken = await _getAccessToken();

    Uri uri = Uri.parse(apiUrl);

    final body = json.encode({
      'function': 'doGet',
      'parameters': {
        'sheet': 'シート1',
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

  Future<dynamic> doPost(String sheetName) async {
    Uri uri = Uri.parse(apiUrl);
    var accessToken = await _getAccessToken();

    DateTime now = DateTime.now();
    DateFormat outputFormat = DateFormat('yyyy/MM/dd hh:mm:ss');
    String time = outputFormat.format(now);
    print(time);

    AttendData attendData = AttendData(1, now, AttendType.clockIn, now);
    Map<String, String> jsonObj = attendData.toJson();

    final body = json.encode({
      'function': 'doPost',
      'parameters': {'sheet': sheetName, 'postData': jsonObj}
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
