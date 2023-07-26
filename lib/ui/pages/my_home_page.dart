import 'dart:async';

import 'package:attendance_manager/ui/components/command_buttons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attend_data.dart';
import '../../services/gas_client.dart';
import '../../services/attendance_service.dart';
import '../../application/constants.dart';

import '../components/data_table_view.dart';
import '../components/dialogs/delete_dialog.dart';
import '../components/dialogs/error_dialog.dart';
import '../components/my_app_bar.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<DataRow> _dataRowList = [];

  late GasClient _gasClient;
  late AttendanceService _attendanceService;

  final ScrollController _scrollController = ScrollController();

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
    _gasClient = GasClient(Constants.clientId, Constants.clientSecret,
        Constants.refreshToken, Constants.tokenUrl, Constants.apiUrl);
    _attendanceService = AttendanceService(_gasClient);

    DateTime now = DateTime.now();
    _clockDate = now;
    _selectedDate = now;
    _isLoading = false;

    Timer.periodic(Constants.wait100Milliseconds, (Timer timer) {
      DateTime now = DateTime.now();
      _clockDate = now;

      setState(() {});
    });

    _getByDateTime(now);
  }

  List<DataColumn> _createDataColumns() {
    List<String> dataColumnLabels = ['名前', '時刻', '種類', '削除'];
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    List<DataColumn> columns = [];
    for (int i = 0; i < dataColumnLabels.length; ++i) {
      String label = dataColumnLabels[i];
      columns.add(DataColumn(label: Text(label, style: style)));
    }

    return columns;
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

  void _updateDataRow() {
    _dataRowList.clear();
    for (int i = 0; i < _dataList.length; ++i) {
      _dataRowList.add(_createDataRowsByAttendData(_dataList[i]));
    }
  }

  void _scrollToEnd() {
    _scrollController.animateTo(_scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100), curve: Curves.ease);
  }

  Future<void> _getByDateTime(DateTime dateTime) async {
    String sheetId = _attendanceService.getSheetId(dateTime);
    String sheetName = _attendanceService.getSheetName(dateTime);

    try {
      _isLoading = true;
      List<AttendData> result =
          await _attendanceService.getByDateTime(sheetId, sheetName, dateTime);
      _dataList.clear();
      _dataList.addAll(result);
      _isLoading = false;
      setState(() {
        _updateDataRow();
      });
      await Future.delayed(Constants.wait100Milliseconds);
      setState(() {
        _scrollToEnd();
      });
    } catch (e) {
      _isLoading = false;
      ErrorDialog.showErrorDialog(context, e);
    }
  }

  Future<void> _deleteRow(AttendData data) async {
    try {
      _isLoading = true;
      debugPrint('delete row');
      String sheetId = _attendanceService.getSheetId(data.dateTime);
      String sheetName = _attendanceService.getSheetName(data.dateTime);
      data.status = Status.deleted;
      List<AttendData> result =
          await _attendanceService.updateById(sheetId, sheetName, data);

      debugPrint('result = $result');

      _dataList.clear();
      _dataList.addAll(result);
      _isLoading = false;

      setState(() {
        _updateDataRow();
      });
    } catch (e) {
      _isLoading = false;
      ErrorDialog.showErrorDialog(context, e);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(_selectedDate.year - 1),
        lastDate: DateTime(_selectedDate.year + 1));
    if (picked == null) {
      return;
    }

    _selectedDate = picked;

    _dataList.clear();
    setState(() {
      _updateDataRow();
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
    _isLoading = true;
  }

  Future<void> _onGetResults(List<AttendData> results) async {
    _dataList.clear();
    _dataList.addAll(results);
    _isLoading = false;

    setState(() {
      _updateDataRow();
    });
    await Future.delayed(Constants.wait100Milliseconds);
    setState(() {
      _scrollToEnd();
    });
  }

  void _onError(Object error) {
    _isLoading = false;
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
              },
            );
          }))
    ]);
  }

  @override
  Widget build(BuildContext context) {
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
                    child: DataTableView(
                        scrollController: _scrollController,
                        columns: _createDataColumns(),
                        rows: _dataRowList,
                        isLoading: _isLoading))),
            //_buttons(),
            CommandButtons(_attendanceService, _chooseName, _selectedDate,
                onPickDate: _onPickDate,
                onGetResults: _onGetResults,
                onError: _onError),
            Padding(padding: Constants.allPadding, child: _nameButtons())
          ])),
        )));
  }
}
