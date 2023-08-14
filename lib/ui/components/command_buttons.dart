import 'package:attendance_manager/ui/components/dialogs/paid_holiday_dialog.dart';
import 'package:flutter/material.dart';

import '../../application/constants.dart';
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
    TextStyle? buttonTextStyle1 = TextStyle(
        color: Colors.black,
        fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize);
    TextStyle? buttonTextStyle2 = TextStyle(
        color: Colors.white,
        fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize);

    double buttonHeight = 50;
    double buttonWidthMulti = 0.4;
    double spaceMulti = 0.033;

    return LayoutBuilder(
        builder: (context, constraints) => Wrap(
                runAlignment: WrapAlignment.center,
                spacing: constraints.maxWidth * spaceMulti,
                runSpacing: 10,
                children: [
                  if (widget.clockIn)
                    SizedBox(
                        width: constraints.maxWidth * buttonWidthMulti,
                        height: buttonHeight,
                        child: ElevatedButton(
                            style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.all<Color?>(
                                        Constants.green)),
                            onPressed: _manualClockIn,
                            child: Text('出勤', style: buttonTextStyle1))),
                  if (widget.clockOut)
                    SizedBox(
                        width: constraints.maxWidth * buttonWidthMulti,
                        height: buttonHeight,
                        child: ElevatedButton(
                            onPressed: _manualClockOut,
                            style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.all<Color?>(
                                        Constants.red)),
                            child: Text('退勤', style: buttonTextStyle1))),
                  SizedBox(
                      width: constraints.maxWidth * buttonWidthMulti,
                      height: buttonHeight,
                      child: ElevatedButton(
                          style: ButtonStyle(
                              backgroundColor:
                                  MaterialStateProperty.all<Color?>(
                                      Constants.yellow)),
                          onPressed: _setPaidHoliday,
                          child: Text('有休', style: buttonTextStyle1))),
                  if (widget.timecard)
                    SizedBox(
                        width: constraints.maxWidth * buttonWidthMulti,
                        height: buttonHeight,
                        child: ElevatedButton(
                            style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.all<Color?>(
                                        Constants.brown)),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => TimecardPage(
                                          service: _attendanceService,
                                          name: widget.name,
                                          dateTime: widget.dateTime)));
                            },
                            child: Text('タイムカード', style: buttonTextStyle1))),
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
          await _attendanceService.setAttendData(sheetId, sheetName, data);

      widget.onGetResults!(results);
    } catch (e) {
      widget.onError!(e);
    }
  }

  Future<void> _setPaidHoliday() async {
    AttendType type = AttendType.paidHoliday;
    PaidHolidayType? paidHolidayType = await showDialog<PaidHolidayType?>(
        context: context,
        builder: (_) {
          return PaidHolidayDialog(
            dateTime: widget.dateTime,
            selectedName: widget.name,
          );
        });

    if (paidHolidayType == null) {
      return;
    }

    try {
      widget.onPickDate!();

      String sheetId = _attendanceService.getSheetId(widget.dateTime);
      String sheetName = _attendanceService.getSheetName(widget.dateTime);
      String name = widget.name;
      DateTime dateTime = DateTime(
          widget.dateTime.year, widget.dateTime.month, widget.dateTime.day);
      AttendData data =
          AttendData(name, type, dateTime, remarks: [paidHolidayType.toStr]);

      List<AttendData> results =
          await _attendanceService.setAttendData(sheetId, sheetName, data);

      widget.onGetResults!(results);
    } catch (e) {
      widget.onError!(e);
    }
  }
}
