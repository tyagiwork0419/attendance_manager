import 'dart:convert';
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

  Future<dynamic> _getAccessToken() async {
    Map<String, String> headers = {'content-type': 'application/json'};
    String body = json.encode({
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'refresh_token': _refreshToken,
      'grant_type': _grantType,
    });

    http.Response response =
        await http.post(Uri.parse(_tokenUrl), headers: headers, body: body);
    var data = jsonDecode(response.body);
    var accessToken = data['access_token'];
    return accessToken;
  }

  Future<dynamic> get(Object parameters) async {
    var accessToken = await _getAccessToken();

    Uri uri = Uri.parse(_apiUrl);

    final body = json.encode({
      'function': 'doGet',
      'parameters': parameters
      /*
      'parameters': {
        'sheet': sheetName,
      }
      */
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

  Future<dynamic> post(Object parameters) async {
    Uri uri = Uri.parse(_apiUrl);
    var accessToken = await _getAccessToken();

    final body = json.encode({
      'function': 'doPost',
      'parameters': parameters,
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
