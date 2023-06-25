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
    print('get access token');
    Map<String, String> headers = {'content-type': 'application/json'};
    String body = json.encode({
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'refresh_token': _refreshToken,
      'grant_type': _grantType,
    });

    print(body);

    http.Response response =
        await http.post(Uri.parse(_tokenUrl), headers: headers, body: body);
      
    print(response.statusCode);

    if(response.statusCode == 200){
      var data = jsonDecode(response.body);
      var accessToken = data['access_token'];
      return accessToken;
    }else{
      throw Exception('get access token error: ${response.body}');
    }
    
  }

  Future<dynamic> get(Object parameters) async {

    var accessToken = await _getAccessToken();

    //oauth2.Client client = await oauth2.clientCredentialsGrant(Uri.parse(_tokenUrl), _clientId, _clientSecret);
    
    Uri uri = Uri.parse(_apiUrl);

    final body = json.encode({
      'function': 'select',
      'parameters': parameters
    });

    //http.Response response = await client.post(uri, body: body);
    Map<String, String> headers = {
      'Authorization': 'Bearer $accessToken',
    };

    http.Response response = await http.post(uri, headers: headers, body: body);

    if(response.statusCode == 200){
      var data = json.decode(response.body);
      print(data);
      String result = data['response']['result'];
      var jsonResult = json.decode(result);
      return jsonResult;

    }else{
      throw Exception(response.body);
    }

  }

  Future<dynamic> post(Object parameters) async {
    Uri uri = Uri.parse(_apiUrl);
    var accessToken = await _getAccessToken();

    final body = json.encode({
      'function': 'insertRows',
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
