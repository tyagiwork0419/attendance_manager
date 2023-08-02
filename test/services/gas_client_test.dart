import 'dart:convert';

import 'package:attendance_manager/application/constants.dart';
import 'package:attendance_manager/models/attend_data.dart';
import 'package:attendance_manager/models/calendar.dart';
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

  test('clientCredentialGrant', () async {
    List<AttendData> dataList = [];
    List<CalendarEvent> eventList = [];

    String result =
        '{"datas":[{"id":90,"name":"八木","type":"出勤","dateTime":"2023/07/28 08:45:00","status":"normal"},{"id":91,"name":"八木","type":"退勤","dateTime":"2023/07/28 18:40:00","status":"normal"},{"id":92,"name":"八木","type":"出勤","dateTime":"2023/07/28 20:30:00","status":"normal"},{"id":93,"name":"八木","type":"退勤","dateTime":"2023/07/28 21:30:00","status":"normal"}],"events":[{"date":"2023/01/01 00:00:00","name":"元日"},{"date":"2023/01/02 00:00:00","name":"休日 元日"},{"date":"2023/01/09 00:00:00","name":"成人の日"},{"date":"2023/02/11 00:00:00","name":"建国記念の日"},{"date":"2023/02/23 00:00:00","name":"天皇誕生日"},{"date":"2023/03/21 00:00:00","name":"春分の日"},{"date":"2023/04/29 00:00:00","name":"昭和の日"},{"date":"2023/05/03 00:00:00","name":"憲法記念日"},{"date":"2023/05/04 00:00:00","name":"みどりの日"},{"date":"2023/05/05 00:00:00","name":"こどもの日"},{"date":"2023/07/17 00:00:00","name":"海の日"},{"date":"2023/08/11 00:00:00","name":"山の日"},{"date":"2023/09/18 00:00:00","name":"敬老の日"},{"date":"2023/09/23 00:00:00","name":"秋分の日"},{"date":"2023/10/09 00:00:00","name":"スポーツの日"},{"date":"2023/11/03 00:00:00","name":"文化の日"},{"date":"2023/11/23 00:00:00","name":"勤労感謝の日"}]}';
    Map<dynamic, dynamic> jsonObj = json.decode(result);
    List<dynamic> datas = jsonObj['datas'];
    for (int i = 0; i < datas.length; ++i) {
      Map<String, dynamic> data = datas[i];
      AttendData attendData = AttendData.fromJson(data);
      dataList.add(attendData);
    }

    List<dynamic> events = jsonObj['events'];
    for (int i = 0; i < events.length; ++i) {
      Map<String, dynamic> event = events[i];
      CalendarEvent calendarEvent = CalendarEvent.fromJson(event);
      eventList.add(calendarEvent);
    }
  });
}
