import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/attend_data.dart';

extension TimeOfDayConverter on TimeOfDay {
  String to24hours() {
    final hour = this.hour.toString().padLeft(2, '0');
    final min = minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}

class DateTimePickerDialog extends StatefulWidget {
  final String selectedName;
  final AttendType selectedType;
  final DateTime dateTime;
  const DateTimePickerDialog(
      {super.key,
      required this.dateTime,
      required this.selectedName,
      required this.selectedType});

  @override
  State<DateTimePickerDialog> createState() => _DateTimePickerDialogState();
}

class _DateTimePickerDialogState extends State<DateTimePickerDialog> {
  String _dateString = '';
  String _timeString = '';
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');

  final TextStyle _textPickerStyle = const TextStyle(fontSize: 20);

  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();

    _date = widget.dateTime;
    _time =
        TimeOfDay(hour: widget.dateTime.hour, minute: widget.dateTime.minute);
    _dateString = _dateFormat.format(_date);
    _timeString = _time.to24hours();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text(widget.selectedType.toStr),
        content: DataTable(
            headingRowColor: MaterialStateColor.resolveWith(
                (states) => const Color.fromARGB(255, 218, 218, 218)),
            border: TableBorder.all(),
            columns: const [
              DataColumn(label: Text('名前')),
              //DataColumn(label: Text('種類')),
              //DataColumn(label: Text('日付')),
              DataColumn(label: Text('日付')),
              DataColumn(label: Text('時刻')),
              //DataColumn(label: Text('削除')),
            ],
            rows: [
              DataRow(cells: [
                DataCell(Text(widget.selectedName)),
                //DataCell(Text(widget.selectedType.toStr)),
                DataCell(TextButton(
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
                )),
                DataCell(TextButton(
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
                    })),
              ])
            ]),
        actions: [
          ElevatedButton(
            child: const Text('決定'),
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
