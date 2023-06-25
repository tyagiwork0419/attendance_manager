import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_manager/services/gas_client.dart';

void main() {
  test('authorizationCodeGrant', () async {
    const clientId = '';
    const clientSecret = '';
    const tokenUrl = '';
    const apiUrl = '';
    const refreshToken = '';

    GasClient client = GasClient(clientId, clientSecret, refreshToken, apiUrl, tokenUrl);


  });

  test('clientCredentialGrant', () async {
    const clientId = '';
    const clientSecret = '';
    const tokenUrl = '';
    const apiUrl = '';
    const refreshToken = '';

    GasClient client = GasClient(clientId, clientSecret, refreshToken, apiUrl, tokenUrl);


  });

}