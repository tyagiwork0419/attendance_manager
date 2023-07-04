import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension TimeOfDayConverter on TimeOfDay {
  String to24hours() {
    final hour = this.hour.toString().padLeft(2, '0');
    final min = minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}

class DateTimePickerDialog extends StatefulWidget {
  const DateTimePickerDialog({super.key});

  @override
  State<DateTimePickerDialog> createState() => _DateTimePickerDialogState();
}

class _DateTimePickerDialogState extends State<DateTimePickerDialog> {
  String _dateString = '';
  String _timeString = '';
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  final TextStyle _textPickerStyle = const TextStyle(fontSize: 20);

  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();

    _date = DateTime.now();
    _time = TimeOfDay.now();
    _dateString = _dateFormat.format(_date);
    _timeString = _time.to24hours();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text('手動設定'),
        content: SizedBox(
            child: Row(children: [
          TextButton(
            child: Text(_dateString, style: _textPickerStyle),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(_date.year - 1),
                  lastDate: DateTime(_date.year + 1));
              if (picked == null) {
                return;
              }
              _date = picked;
              setState(() {
                _dateString = _dateFormat.format(_date);
              });
            },
          ),
          TextButton(
              child: Text(_timeString, style: _textPickerStyle),
              onPressed: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                  initialEntryMode: TimePickerEntryMode.dial,
                );
                if (picked == null) {
                  return;
                }
                _time = picked;

                setState(() {
                  _timeString = _time.to24hours();
                });
              }),
        ])),
        actions: [
          ElevatedButton(
            child: const Text('OK'),
            onPressed: () {
              DateTime dateTime = DateTime(
                  _date.year, _date.month, _date.day, _time.hour, _time.minute);
              Navigator.of(context).pop(dateTime);
            },
          ),
          ElevatedButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop(null);
              }),
        ]);
  }
}
