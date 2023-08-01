import 'package:attendance_manager/application/constants.dart';
import 'package:attendance_manager/models/attend_data.dart';
import 'package:attendance_manager/services/attendance_service.dart';
import 'package:attendance_manager/services/gas_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authorizationCodeGrant', () async {
    GasClient gasClient = GasClient(Constants.clientId, Constants.clientSecret,
        Constants.refreshToken, Constants.tokenUrl, Constants.apiUrl);

    AttendanceService service = AttendanceService(gasClient);

    await service.getEvents();
  });

  test('clientCredentialGrant', () async {});
}
