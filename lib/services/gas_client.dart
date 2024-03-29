import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class GasClient {
  late final String _clientId;
  late final String _clientSecret;
  late final String _refreshToken;
  late final String _tokenUrl;
  late final String _apiUrl;
  final String _grantType = 'refresh_token';

  GasClient(this._clientId, this._clientSecret, this._refreshToken,
      this._tokenUrl, this._apiUrl);

  Future<String> getAccessToken() async {
    debugPrint('get access token');
    Map<String, String> headers = {'content-type': 'application/json'};
    String body = json.encode({
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'refresh_token': _refreshToken,
      'grant_type': _grantType,
    });

    debugPrint(body);

    http.Response response =
        await http.post(Uri.parse(_tokenUrl), headers: headers, body: body);

    debugPrint(response.statusCode.toString());

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      String accessToken = data['access_token'];
      return accessToken;
    } else {
      throw Exception('get access token error: ${response.body}');
    }
  }

  Future<String> post(String functionName, Object parameters) async {
    String accessToken = await getAccessToken();

    Uri uri = Uri.parse(_apiUrl);

    final body =
        json.encode({'function': functionName, 'parameters': parameters});

    Map<String, String> headers = {
      'Authorization': 'Bearer $accessToken',
    };

    http.Response response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      debugPrint('data = $data');
      String result = data['response']['result'];
      return result;
    } else {
      throw Exception(response.body);
    }
  }
}
