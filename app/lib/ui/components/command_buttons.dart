import 'package:attendance_manager/ui/components/dialogs/paid_holiday_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../application/constants.dart';
import '../../models/attend_data.dart';
import '../../services/attendance_service.dart';
import '../../services/gas_client.dart';
import '../pages/timecard_page.dart';
import 'dialogs/datetime_picker_dialog.dart';
import 'dialogs/error_dialog.dart';
import 'dialogs/loading_overlay.dart';
import 'dialogs/login_dialog.dart';

class CommandButtons extends StatefulWidget {
  final bool clockIn;
  final bool clockOut;
  final bool timecard;
  final AttendanceService attendanceService;
  final String name;
  final DateTime dateTime;

  /// 表示中の日のデータ。出退勤が連続していないかの判定に使う。
  final List<AttendData> dataList;

  final VoidCallback? onPickDate;
  final void Function(List<AttendData> results)? onGetResults;
  final void Function(Object error)? onError;

  //final

  const CommandButtons(
    this.attendanceService,
    this.name,
    this.dateTime, {
    super.key,
    required this.dataList,
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
    /*
    TextStyle? buttonTextStyle2 = TextStyle(
        color: Colors.white,
        fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize);
        */

    double buttonHeight = 50;
    double buttonWidthMulti = 0.4;
    double spaceMulti = 0.066;

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
                            onPressed: _openTimecard,
                            child: Text('タイムカード', style: buttonTextStyle1))),
                ]));
  }

  Future<void> _manualClockIn() async {
    await _manualInput(AttendType.clockIn);
  }

  Future<void> _manualClockOut() async {
    await _manualInput(AttendType.clockOut);
  }

  /// 同じ種類の打刻が連続しないか調べる。問題があればその理由を返す。
  ///
  /// 打刻ダイアログで変更できるのは時刻だけで、日付は表示中の日から動かない。
  /// そのため画面が持っているその日のデータだけで判定できる。
  String? _findSequenceConflict(AttendType type, DateTime dateTime) {
    // 有休は出退勤の並びとは独立しているので対象外。
    if (type != AttendType.clockIn && type != AttendType.clockOut) {
      return null;
    }

    List<AttendData> sequence = widget.dataList
        .where((AttendData data) =>
            data.name == widget.name &&
            (data.type == AttendType.clockIn ||
                data.type == AttendType.clockOut))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // 時刻を選び直して既存の打刻の間に入れることもできるため、
    // 直前だけでなく直後も確認する。
    AttendData? previous;
    AttendData? next;
    for (AttendData data in sequence) {
      if (data.dateTime.isAfter(dateTime)) {
        next ??= data;
      } else {
        previous = data;
      }
    }

    AttendData? conflict;
    if (previous != null && previous.type == type) {
      conflict = previous;
    } else if (next != null && next.type == type) {
      conflict = next;
    }

    if (conflict == null) {
      return null;
    }

    String time = DateFormat('HH:mm').format(conflict.dateTime);
    String required = type == AttendType.clockIn
        ? AttendType.clockOut.toStr
        : AttendType.clockIn.toStr;

    return '$time に${type.toStr}が記録されています。\n先に$requiredを記録してください。';
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

    String? conflict = _findSequenceConflict(type, dateTime);
    if (conflict != null) {
      if (!mounted) {
        return;
      }
      await ErrorDialog.showMessage(context,
          title: '打刻できません', content: conflict);
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

  /// タイムカードを開く。
  ///
  /// 自分名義で登録した端末から自分の分を見る場合はパスワード不要。
  /// それ以外はサーバーが unauthorized を返すので、そこで初めて本人確認を求める。
  /// 権限判定はサーバーが持っているため、クライアント側では条件を重複させない。
  /// [allowRetry] は本人確認をやり直せる回数を1回に限るためのもの。
  /// ログイン後もサーバーが拒否し続けた場合に無限に繰り返さないようにする。
  Future<void> _openTimecard({bool allowRetry = true}) async {
    try {
      // 応答を待つ間に同じボタンを押せてしまわないよう、操作を止める。
      List<AttendData> results =
          await LoadingOverlay.during(context, () async {
        String sheetId = _attendanceService.getSheetId(widget.dateTime);
        String sheetName = _attendanceService.getSheetName(widget.dateTime);

        return _attendanceService.getByName(sheetId, sheetName, widget.name);
      });

      if (!mounted) {
        return;
      }
      // 取得済みのデータを渡す。遷移先で同じ問い合わせを繰り返さないため。
      _transitionToTimecardPage(results);
    } on GasException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.isUnauthorized && allowRetry) {
        if (await _promptLogin()) {
          await _openTimecard(allowRetry: false);
        }
        return;
      }
      widget.onError!(e);
    } catch (e) {
      widget.onError!(e);
    }
  }

  /// 本人確認のダイアログを出す。成功したら true。
  Future<bool> _promptLogin() async {
    bool? result = await showDialog<bool?>(
        context: context,
        builder: (_) {
          return LoginDialog(
            selectedName: widget.name,
            attendanceService: _attendanceService,
          );
        });

    return result == true && mounted;
  }

  void _transitionToTimecardPage(List<AttendData> initialData) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => TimecardPage(
                service: _attendanceService,
                name: widget.name,
                dateTime: widget.dateTime,
                initialData: initialData)));
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
