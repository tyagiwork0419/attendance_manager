import 'package:flutter/material.dart';

import '../../models/attend_data.dart';
import '../../services/attendance_service.dart';
import '../pages/timecard_page.dart';
import 'dialogs/datetime_picker_dialog.dart';

class CommandButtons extends StatefulWidget {
  final bool clockIn;
  final bool clockOut;
  final bool timecard;
  final AttendanceService attendanceService;
  final String name;
  final DateTime dateTime;
  final VoidCallback? onPickDate;
  final void Function(List<AttendData> results)? onGetResults;
  final void Function(Object error)? onError;

  //final

  const CommandButtons(
    this.attendanceService,
    this.name,
    this.dateTime, {
    super.key,
    this.clockIn = true,
    this.clockOut = true,
    this.timecard = true,
    this.onPickDate,
    this.onGetResults,
    this.onError,
  });

  @override
  State<CommandButtons> createState() => _CommandButtonsState();
}

class _CommandButtonsState extends State<CommandButtons> {
  late AttendanceService _attendanceService;

  @override
  void initState() {
    super.initState();
    _attendanceService = widget.attendanceService;
  }

  @override
  Widget build(BuildContext context) {
    TextStyle? buttonTextStyle = TextStyle(
        color: Colors.white,
        fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize);

    double buttonHeight = 50;
    double spaceMulti = 0.025;
    double buttonWidthMulti = 0.3;

    return LayoutBuilder(
        builder: (context, constraints) => Wrap(
                runAlignment: WrapAlignment.center,
                spacing: constraints.maxWidth * spaceMulti,
                children: [
                  if (widget.clockIn)
                    SizedBox(
                        width: constraints.maxWidth * buttonWidthMulti,
                        height: buttonHeight,
                        child: ElevatedButton(
                            onPressed: _manualClockIn,
                            child: Text('出勤', style: buttonTextStyle))),
                  if (widget.clockOut)
                    SizedBox(
                        width: constraints.maxWidth * buttonWidthMulti,
                        height: buttonHeight,
                        child: ElevatedButton(
                            onPressed: _manualClockOut,
                            child: Text('退勤', style: buttonTextStyle))),
                  if (widget.timecard)
                    SizedBox(
                        width: constraints.maxWidth * buttonWidthMulti,
                        height: buttonHeight,
                        child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => TimecardPage(
                                          service: _attendanceService,
                                          name: widget.name,
                                          dateTime: widget.dateTime)));
                            },
                            child: Text('タイムカード', style: buttonTextStyle))),
                ]));
  }

  Future<void> _manualClockIn() async {
    await _manualInput(AttendType.clockIn);
  }

  Future<void> _manualClockOut() async {
    await _manualInput(AttendType.clockOut);
  }

  Future<void> _manualInput(AttendType type) async {
    DateTime? dateTime = await showDialog<DateTime?>(
        context: context,
        builder: (_) {
          return DateTimePickerDialog(
              dateTime: widget.dateTime,
              //nameList: _nameList,
              selectedName: widget.name,
              selectedType: type);
        });

    if (dateTime == null) {
      return;
    }
    try {
      widget.onPickDate!();

      String sheetId = _attendanceService.getSheetId(dateTime);
      String sheetName = _attendanceService.getSheetName(dateTime);
      String name = widget.name;
      AttendData data = AttendData(name, type, dateTime);

      List<AttendData> results =
          await _attendanceService.setClock(sheetId, sheetName, data);

      widget.onGetResults!(results);
    } catch (e) {
      widget.onError!(e);
    }
  }
}
