import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/attend_data.dart';

/*
extension TimeOfDayConverter on TimeOfDay {
  String to24hours() {
    final hour = this.hour.toString().padLeft(2, '0');
    final min = minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}
*/

class PaidHolidayDialog extends StatefulWidget {
  final String selectedName;
  //final AttendType selectedType;
  final DateTime dateTime;

  const PaidHolidayDialog({
    super.key,
    required this.dateTime,
    required this.selectedName,
  }); //required this.selectedType});

  @override
  State<PaidHolidayDialog> createState() => _PaidHolidayDialogState();
}

class _PaidHolidayDialogState extends State<PaidHolidayDialog> {
  String _dateString = '';
  //String _timeString = '';
  //final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  final DateFormat _dateFormat = DateFormat('MM/dd');
  final list = <PaidHolidayType>[PaidHolidayType.full, PaidHolidayType.half];

  final TextStyle _textPickerStyle = const TextStyle(fontSize: 20);

  late DateTime _date;
  late PaidHolidayType _selectedValue;
  //late TimeOfDay _time;

  @override
  void initState() {
    super.initState();

    _date = widget.dateTime;
    _dateString = _dateFormat.format(_date);
    _selectedValue = list[0];
    //_timeString = _time.to24hours();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text(AttendType.paidHoliday.toStr),
        content: FittedBox(
            child: DataTable(
                headingRowColor: MaterialStateColor.resolveWith(
                    (states) => const Color.fromARGB(255, 218, 218, 218)),
                border: TableBorder.all(),
                columns: const [
              DataColumn(label: Text('名前')),
              DataColumn(label: Text('日付')),
              DataColumn(label: Text('種類')),
            ],
                rows: [
              DataRow(cells: [
                DataCell(Text(widget.selectedName)),
                //DataCell(Text(widget.selectedType.toStr)),
                //DataCell(TextButton(
                DataCell(
                  Text(_dateString, style: _textPickerStyle),

                  /*
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
                  */
                ),
                DataCell(DropdownButton<PaidHolidayType>(
                  value: _selectedValue,
                  items: list
                      .map((PaidHolidayType item) =>
                          DropdownMenuItem<PaidHolidayType>(
                              value: item, child: Text(item.toStr)))
                      .toList(),
                  onChanged: (PaidHolidayType? value) {
                    setState(() {
                      _selectedValue = value!;
                    });
                  },
                )),
              ])
            ])),
        actions: [
          ElevatedButton(
            child: const Text('決定'),
            onPressed: () {
              Navigator.of(context).pop(_selectedValue);
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
