import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../application/ja_am_pm_localizations.dart';
import '../../../models/attend_data.dart';

/// タイムカードから、その日の打刻を追加するダイアログ。
///
/// 打ち忘れた出勤・退勤を後から入れるためのもの。
/// 既存の打刻の時刻を書き換えることはできない（GAS 側の updateById が
/// status しか更新しないため）。修正したい場合はホーム画面でその日を開き、
/// 削除してから入れ直す。
class PunchInputDialog extends StatefulWidget {
  final String name;

  /// 対象の日。時刻部分は使わない。
  final DateTime date;

  /// その日の現状。参考として表示するだけで編集はできない。
  final String clockInTimeStr;
  final String clockOutTimeStr;

  const PunchInputDialog({
    super.key,
    required this.name,
    required this.date,
    required this.clockInTimeStr,
    required this.clockOutTimeStr,
  });

  @override
  State<PunchInputDialog> createState() => _PunchInputDialogState();
}

class _PunchInputDialogState extends State<PunchInputDialog> {
  static final DateFormat _dateFormat = DateFormat('MM/dd(E)', 'ja');

  AttendType _type = AttendType.clockIn;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _time = _defaultTimeFor(_type);
  }

  /// 打ち忘れを埋める用途なので、種類に応じた妥当な時刻から始める。
  TimeOfDay _defaultTimeFor(AttendType type) {
    return type == AttendType.clockIn
        ? const TimeOfDay(hour: 9, minute: 0)
        : const TimeOfDay(hour: 18, minute: 0);
  }

  void _onTypeChanged(AttendType? type) {
    if (type == null) {
      return;
    }
    setState(() {
      _type = type;
      _time = _defaultTimeFor(type);
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time,
      initialEntryMode: TimePickerEntryMode.dial,
      // AM / PM で選べるようにする。ja の標準表記は24時間制なので、
      // 時刻ピッカーの間だけローカライズを差し替える。
      builder: (context, child) => Localizations.override(
        context: context,
        delegates: const [JaAmPmMaterialLocalizations.delegate],
        child: child,
      ),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _time = picked;
    });
  }

  void _submit() {
    final DateTime dateTime = DateTime(widget.date.year, widget.date.month,
        widget.date.day, _time.hour, _time.minute);

    Navigator.of(context).pop(AttendData(widget.name, _type, dateTime));
  }

  String get _timeStr =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    return AlertDialog(
      title: Text('${_dateFormat.format(widget.date)} の打刻を追加'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '現在の記録　出勤: ${_orDash(widget.clockInTimeStr)}'
                '　退勤: ${_orDash(widget.clockOutTimeStr)}',
                style: style,
              ),
            ),
            RadioListTile<AttendType>(
              value: AttendType.clockIn,
              groupValue: _type,
              onChanged: _onTypeChanged,
              title: Text(AttendType.clockIn.toStr),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<AttendType>(
              value: AttendType.clockOut,
              groupValue: _type,
              onChanged: _onTypeChanged,
              title: Text(AttendType.clockOut.toStr),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('時刻', style: style),
                TextButton(
                  onPressed: _pickTime,
                  child: Text(_timeStr,
                      style: const TextStyle(fontSize: 20)),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(onPressed: _submit, child: const Text('決定')),
        ElevatedButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('キャンセル')),
      ],
    );
  }

  static String _orDash(String value) => value.isEmpty ? '—' : value;
}
