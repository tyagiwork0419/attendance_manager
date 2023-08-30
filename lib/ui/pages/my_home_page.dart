import 'dart:async';
import 'dart:math';

import 'package:attendance_manager/ui/components/command_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_expandable_table/flutter_expandable_table.dart';
import 'package:intl/intl.dart';

import '../../models/attend_data.dart';
import '../../services/attendance_service.dart';
import '../../application/constants.dart';

import '../components/data_table_view.dart';
import '../components/dialogs/delete_dialog.dart';
import '../components/dialogs/error_dialog.dart';
import '../components/my_app_bar.dart';

//import 'package:linked_scroll_controller/linked_scroll_controller.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage(
      {super.key, required this.title, required this.attendanceService});

  final String title;
  final AttendanceService attendanceService;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<DataRow> _dataRowList = [];

  //late GasClient _gasClient;
  late AttendanceService _attendanceService;

  //late LinkedScrollControllerGroup _verticalLinkedControllers;
  //late LinkedScrollControllerGroup _horizontalLinkedControllers;
  //late ScrollController _bodyController;
  //final ScrollController _scrollController = ScrollController();

  late DateTime _clockDate;
  late DateTime _selectedDate;

  final List<AttendData> _dataList = [];
  late bool _isLoading;

  int _choiceIndex = 0;
  String get _chooseName {
    return Constants.nameList[_choiceIndex];
  }

  @override
  void initState() {
    super.initState();

    //_horizontalLinkedControllers = LinkedScrollControllerGroup();
    //_verticalLinkedControllers = LinkedScrollControllerGroup();
    //_bodyController = _verticalLinkedControllers.addAndGet();

    _attendanceService = widget.attendanceService;

    DateTime now = DateTime.now();
    _clockDate = now;
    _selectedDate = now;
    _isLoading = false;

    Timer.periodic(Constants.wait100Milliseconds, (Timer timer) {
      DateTime now = DateTime.now();

      if (_clockDate.difference(now) >= const Duration(minutes: 1)) {
        setState(() {
          _clockDate = now;
        });
      }
    });

    _getByDateTime(now);
  }

  ExpandableTableCell _createFirstHeaderCell() {
    return DataTableView.buildCell(const Text('名前'), color: Constants.gray);
  }

  List<ExpandableTableHeader> _createHeaders() {
    final List<String> labels = ['時刻', '種類', '削除'];
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    List<ExpandableTableHeader> headers = [];
    for (int i = 0; i < labels.length; ++i) {
      String label = labels[i];
      headers.add(ExpandableTableHeader(
          cell: DataTableView.buildCell(
              Text(
                label,
                style: style,
              ),
              color: Constants.gray)));
    }

    return headers;
  }

  List<ExpandableTableRow> _createRows() {
    List<ExpandableTableRow> rows = [];
    for (int i = 0; i < _dataList.length; ++i) {
      AttendData data = _dataList[i];
      String typeStr = data.type.toStr;
      if (data.type == AttendType.paidHoliday) {
        typeStr = data.remarksToString(', ');
      }

      Color color;
      TextStyle? style = Theme.of(context).textTheme.bodyMedium;

      switch (data.type) {
        case AttendType.clockIn:
          color = Constants.green;
          break;
        case AttendType.clockOut:
          color = Constants.red;
          break;
        case AttendType.paidHoliday:
          color = Constants.yellow;
          break;

        default:
          color = Colors.white;
      }

      ExpandableTableCell dateTime = DataTableView.buildCell(
          Text(data.shortDateTimeStr, style: style),
          color: color);
      ExpandableTableCell type =
          DataTableView.buildCell(Text(typeStr, style: style), color: color);
      ExpandableTableCell delete = DataTableView.buildCell(
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              debugPrint('presseed');
              bool? delete = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) {
                    return const DeleteDialog();
                  });

              if (delete!) {
                _deleteRow(data);
              }
            },
          ),
          color: color);

      ExpandableTableCell firstCell = DataTableView.buildFirstRowCell(
          child: Text(data.name, style: style), color: color);
      List<ExpandableTableCell> cells = [dateTime, type, delete];
      ExpandableTableRow row =
          ExpandableTableRow(firstCell: firstCell, cells: cells);

      rows.add(row);
    }

    return rows;
  }

  DataRow _createDataRowsByAttendData(AttendData data) {
    String name = data.name;
    String dateTime = data.shortDateTimeStr;
    String type = data.type.toStr;
    Color color;
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    switch (data.type) {
      case AttendType.clockIn:
        color = Constants.green;
        break;
      case AttendType.clockOut:
        color = Constants.red;
        break;

      default:
        color = Colors.white;
    }

    DataRow dataRow = DataRow(
        color: MaterialStateColor.resolveWith((states) => color),
        cells: [
          DataCell(Text(name, style: style)),
          DataCell(Text(dateTime, style: style)),
          DataCell(Text(type, style: style)),
          DataCell(IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              debugPrint('presseed');
              bool? delete = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) {
                    return const DeleteDialog();
                  });

              if (delete!) {
                _deleteRow(data);
              }
            },
          )),
        ]);

    return dataRow;
  }

  void _updateDataRow(List<AttendData> results) {
    _dataList.clear();
    _dataList.addAll(results);
    _dataRowList.clear();
    for (int i = 0; i < _dataList.length; ++i) {
      _dataRowList.add(_createDataRowsByAttendData(_dataList[i]));
    }
  }

  void _scrollToEnd() {
    //_verticalLinkedControllers.animateTo(
    //_horizontalLinkedControllers.
    /*
    print('maxScrollExtent = ${_bodyController.position.maxScrollExtent}');
    _horizontalLinkedControllers.animateTo(
        _bodyController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.ease);
        */
  }

  Future<void> _getByDateTime(DateTime dateTime) async {
    String sheetId = _attendanceService.getSheetId(dateTime);
    String sheetName = _attendanceService.getSheetName(dateTime);

    try {
      setState(() {
        _isLoading = true;
      });
      List<AttendData> result =
          await _attendanceService.getByDateTime(sheetId, sheetName, dateTime);
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _updateDataRow(result);
      });
      await Future.delayed(Constants.wait100Milliseconds);
      if (!mounted) {
        return;
      }

      setState(() {
        _scrollToEnd();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ErrorDialog.showErrorDialog(context, e);
    }
  }

  Future<void> _deleteRow(AttendData data) async {
    try {
      setState(() {
        _isLoading = true;
      });
      debugPrint('delete row');
      String sheetId = _attendanceService.getSheetId(data.dateTime);
      String sheetName = _attendanceService.getSheetName(data.dateTime);
      data.status = Status.deleted;
      List<AttendData> result =
          await _attendanceService.updateById(sheetId, sheetName, data);
      if (!mounted) {
        return;
      }

      debugPrint('result = $result');

      setState(() {
        _isLoading = false;
        _updateDataRow(result);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ErrorDialog.showErrorDialog(context, e);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        locale: const Locale(Constants.locale),
        firstDate: DateTime(_selectedDate.year - 1),
        lastDate: DateTime(_selectedDate.year + 1));
    if (picked == null) {
      return;
    }

    _selectedDate = picked;

    setState(() {
      _updateDataRow([]);
    });

    _getByDateTime(picked);
  }

  Widget _clock(DateTime clock) {
    final DateFormat dateFormat =
        DateFormat('yyyy年MM月dd日(E) HH時mm分', Constants.locale);
    TextStyle? clockTextStyle = Theme.of(context).textTheme.headlineSmall;
    String clockString = dateFormat.format(clock);
    return Center(
      child: Text(clockString, style: clockTextStyle),
    );
  }

  Widget _dateButton(DateTime date, VoidCallback onPressed) {
    final DateFormat dateFormat = DateFormat('yyyy年MM月dd日');
    return Center(
        child: ElevatedButton(
      //child: Text(_dateFormat.format(_selectedDate)),
      child: Text(dateFormat.format(date)),
      onPressed: () {
        onPressed();
      },
    ));
  }

  void _onPickDate() {
    setState(() {
      _isLoading = true;
    });
  }

  Future<void> _onGetResults(List<AttendData> results) async {
    setState(() {
      _isLoading = false;
      _updateDataRow(results);
    });
    await Future.delayed(Constants.wait100Milliseconds);
    if (!mounted) {
      return;
    }

    setState(() {
      _scrollToEnd();
    });
  }

  void _onError(Object error) {
    setState(() {
      _isLoading = false;
    });
  }

  Widget _nameButtons() {
    TextStyle? choiceTextStyle = Theme.of(context).textTheme.headlineSmall;
    return Column(children: [
      Wrap(
          spacing: 10,
          children:
              // _choiceChipList)]),
              List<ChoiceChip>.generate(Constants.nameList.length, (int index) {
            return ChoiceChip(
              label: Text(Constants.nameList[index], style: choiceTextStyle),
              selectedColor: Colors.yellow,
              selected: _choiceIndex == index,
              onSelected: (selected) {
                _choiceIndex = index;
                setState(() {});
              },
            );
          }))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime dateTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, now.hour, now.minute, now.second);

    return Scaffold(
        appBar: MyAppBar(title: widget.title, version: Constants.version)
            .appBar(context),
        body: SingleChildScrollView(
            child: Padding(
          padding: Constants.allPadding,
          child: Center(
              child: Column(children: [
            SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.05,
                child: _clock(_clockDate)),
            SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.05,
                child: _dateButton(_selectedDate, _selectDate)),
            Padding(
                padding: Constants.topBottomPadding,
                child: SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: LayoutBuilder(
                        builder: (context, constraints) => DataTableView(
                            //horizontalLinkedControllers:
                            //    _horizontalLinkedControllers,
                            //verticalLinkedControllers:
                            //    _verticalLinkedControllers,
                            //bodyController: _bodyController,
                            firstHeaderCell: _createFirstHeaderCell(),
                            headers: _createHeaders(),
                            rows: _createRows(),
                            firstColumnWidth:
                                max(120, constraints.maxWidth * 0.25),
                            defaultsColumnWidth:
                                max(120, constraints.maxWidth * 0.25),
                            headerHeight: 60,
                            defaultsRowHeight: 60,
                            isLoading: _isLoading)))),
            //_buttons(),
            CommandButtons(_attendanceService, _chooseName, dateTime,
                onPickDate: _onPickDate,
                onGetResults: _onGetResults,
                onError: _onError),
            Padding(padding: Constants.allPadding, child: _nameButtons())
          ])),
        )));
  }
}
