import 'dart:math';

import 'package:attendance_manager/models/monthly_timecard.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_expandable_table/flutter_expandable_table.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:nil/nil.dart';

import 'package:universal_html/html.dart' as html;

import '../../application/constants.dart';
import '../../models/attend_data.dart';
import '../../models/daily_timecard.dart';
import '../../models/encoder.dart';
import '../../models/punch_sequence.dart';
import '../../models/timecard_data.dart';
import '../../services/attendance_service.dart';
import '../components/data_table_view.dart';
import '../components/dialogs/error_dialog.dart';
import '../components/dialogs/punch_input_dialog.dart';
import '../components/my_app_bar.dart';

class TimecardPage extends StatefulWidget {
  final AttendanceService service;
  final String title;
  final String name;
  final DateTime dateTime;

  /// 遷移元で取得済みの [dateTime] の月のデータ。
  ///
  /// 遷移元は権限確認のために同じ問い合わせを既に済ませているので、
  /// その結果を受け取って初回の再取得を省く。
  final List<AttendData> initialData;

  const TimecardPage(
      {super.key,
      required this.service,
      //required this.title,
      required this.name,
      required this.dateTime,
      required this.initialData})
      : title = 'タイムカード ( $name )';

  @override
  State<TimecardPage> createState() => _TimecardPageState();
}

class _TimecardPageState extends State<TimecardPage> {
  late String _name;
  late AttendanceService _service;

  late MonthlyTimecard? _monthlyTimecard;

  final DateFormat _yearMonthFormat = DateFormat('yyyy年MM月');

  late DateTime _selectedDate;

  late bool _isLoading;

  /// 表のデータ列。CSV の見出しにもそのまま使うので、
  /// 操作用の「編集」列はここには含めない。
  List<String> get _columnNames {
    return ['日付', '出勤', '退勤', '時間', '備考'];
  }

  /// 打刻を追加するボタンを置く列。
  static const String _editColumnName = '編集';

  /// 日付列を含めた表全体の列数。
  int get _columnCount => _columnNames.length + 1;

  /// その月の生データ。打刻の重複判定に使うので保持しておく。
  List<AttendData> _attendDataList = [];

  @override
  void initState() {
    super.initState();

    _service = widget.service;
    _isLoading = false;

    _name = widget.name;
    _selectedDate = widget.dateTime;

    // 遷移元が取得済みのデータで初期化する。
    // 以前はここで DateTime.now() の月を取り直していたため、
    // 別の月を選んで開くと月表示と中身が食い違っていた。
    _monthlyTimecard = null;
    _updateTimecard(widget.initialData);
  }

  ExpandableTableCell _createFirstHeaderCell() {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    String label = _columnNames.first;
    return DataTableView.buildCell(Text(label, style: style),
        color: Constants.gray);
  }

  List<ExpandableTableHeader> _createHeaders() {
    final List<String> labels = [..._columnNames.sublist(1), _editColumnName];
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    List<ExpandableTableHeader> headers = [];
    for (int i = 0; i < labels.length; ++i) {
      String label = labels[i];
      headers.add(ExpandableTableHeader(
          cell: DataTableView.buildCell(Text(label, style: style),
              color: Constants.gray)));
    }

    return headers;
  }

  // 列生成
  List<ExpandableTableRow> _createRows() {
    List<ExpandableTableRow> rows = [];
    if (_monthlyTimecard == null) {
      return rows;
    }
    _monthlyTimecard!.dailyTimecards.forEach((day, dailyTimecard) {
      rows.add(_createRow(dailyTimecard));
    });

    //合計
    rows.add(_createSum(_monthlyTimecard!));

    return rows;
  }

  // 各列生成
  ExpandableTableRow _createRow(DailyTimecard timecard) {
    Color color;
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    if (timecard.hasError) {
      color = Colors.red;
    } else if (timecard.isHoliday) {
      color = Constants.red;
    } else {
      color = Constants.green;
    }

    ExpandableTableCell clockInTime = DataTableView.buildCell(
        Text(
          timecard.clockInTimeStr,
          style: style,
        ),
        color: color);
    ExpandableTableCell clockOutTime = DataTableView.buildCell(
        Text(timecard.clockOutTimeStr, style: style),
        color: color);
    ExpandableTableCell elapsedTime = DataTableView.buildCell(
        Text(timecard.elapsedTimeStr, style: style),
        color: color);

    ExpandableTableCell remarks = DataTableView.buildCell(
        Text(timecard.remarksStr, style: style),
        color: color);

    ExpandableTableCell firstCell = DataTableView.buildFirstRowCell(
        child: Text(timecard.monthDayStr, style: style), color: color);
    List<ExpandableTableCell> cells = [
      //date,
      clockInTime,
      clockOutTime,
      elapsedTime,
      remarks,
      _createEditCell(timecard, color),
    ];

    List<ExpandableTableRow> children = [];
    List<TimecardData>? dataList = timecard.dataList;
    if (timecard.hasMultipleData) {
      for (int i = 0; i < dataList.length; ++i) {
        var data = dataList[i];
        children.add(_createDataRowByData(data, color));
      }
    }
    ExpandableTableRow row = ExpandableTableRow(
        firstCell: firstCell, cells: cells, children: children);

    return row;
  }

  ExpandableTableRow _createDataRowByData(TimecardData data, Color color) {
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    var clockInTime = DataTableView.buildCell(
        Text(data.clockInTimeStr, style: style),
        color: color);
    var clockOutTime = DataTableView.buildCell(
        Text(data.clockOutTimeStr, style: style),
        color: color);
    var elapsedTime = DataTableView.buildCell(
        Text(data.elapsedTimeStr, style: style),
        color: color);
    var remarks = DataTableView.buildCell(Text(data.remarksStr, style: style),
        color: color);

    var row = ExpandableTableRow(
        firstCell: DataTableView.buildCell(nil, color: color),
        cells: [
          clockInTime,
          clockOutTime,
          elapsedTime,
          remarks,
          // 編集は日付の行にだけ置く。内訳の行では列数を合わせるだけ。
          DataTableView.buildCell(nil, color: color),
        ]);

    return row;
  }

  /// 打刻を追加するボタン。
  ExpandableTableCell _createEditCell(DailyTimecard timecard, Color color) {
    return DataTableView.buildCell(
      IconButton(
        icon: const Icon(Icons.edit),
        tooltip: '打刻を追加',
        onPressed: _isLoading ? null : () => _addPunch(timecard),
      ),
      color: color,
    );
  }

  ExpandableTableRow _createSum(MonthlyTimecard monthlyTimecard) {
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    Color color = Colors.green;
    var clockInTime = DataTableView.buildCell(nil, color: color);
    var clockOutTime = DataTableView.buildCell(nil, color: color);
    var elapsedTime = DataTableView.buildCell(
        Text(monthlyTimecard.sumOfElapsedTimeStr, style: style),
        color: color);
    var remarks = DataTableView.buildCell(nil, color: color);

    var row = ExpandableTableRow(
        firstCell:
            DataTableView.buildCell(Text('計', style: style), color: color),
        cells: [
          clockInTime,
          clockOutTime,
          elapsedTime,
          remarks,
          DataTableView.buildCell(nil, color: color),
        ]);

    return row;
  }

  /// その日に打刻を追加する。
  ///
  /// 既存の打刻の時刻は変えられない。GAS の updateById が status しか
  /// 更新しないため、時刻の修正はホーム画面でその日を開いて削除し、
  /// 入れ直す操作になる。
  Future<void> _addPunch(DailyTimecard timecard) async {
    AttendData? data = await showDialog<AttendData?>(
        context: context,
        builder: (_) {
          return PunchInputDialog(
            name: _name,
            date: timecard.date,
            clockInTimeStr: timecard.clockInTimeStr,
            clockOutTimeStr: timecard.clockOutTimeStr,
          );
        });

    if (data == null || !mounted) {
      return;
    }

    // ホーム画面の打刻ボタンと同じ基準で重ならないか確かめる。
    String? conflict = PunchSequence.findConflict(
      dataList: _attendDataList,
      name: _name,
      type: data.type,
      dateTime: data.dateTime,
    );
    if (conflict != null) {
      await ErrorDialog.showMessage(context,
          title: '打刻できません', content: conflict);
      return;
    }

    String sheetId = _service.getSheetId(data.dateTime);
    String sheetName = _service.getSheetName(data.dateTime);

    try {
      setState(() {
        _isLoading = true;
      });

      // insertRows はその日ぶんしか返さないので、表の作り直しには使えない。
      // 追加後に月ぶんを取り直す。
      await _service.setAttendData(sheetId, sheetName, data);
      List<AttendData> result =
          await _service.getByName(sheetId, sheetName, _name);

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _updateTimecard(result);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      ErrorDialog.showErrorDialog(context, e);
    }
  }

  Future<void> _getByName(String name, DateTime dateTime) async {
    String sheetId = _service.getSheetId(dateTime);
    String sheetName = _service.getSheetName(dateTime);

    try {
      // setState の外で立てていたため再描画されず、取得中の表示が出ていなかった。
      setState(() {
        _isLoading = true;
      });

      List<AttendData> result =
          await _service.getByName(sheetId, sheetName, name);
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _updateTimecard(result);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      ErrorDialog.showErrorDialog(context, e);
    }
  }

  void _updateTimecard(List<AttendData> dataList) {
    _attendDataList = dataList;
    _monthlyTimecard = _service.createMonthlyTimecard(
        _name, _selectedDate.year, _selectedDate.month, dataList);
  }

  Future<void> _selectMonth() async {
    var selectedDate = await showMonthPicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(_selectedDate.year - 1),
      lastDate: DateTime(_selectedDate.year + 1),
    );

    // 選択がキャンセルされた場合はNULL
    if (selectedDate == null) return;

    // 選択されて日付で更新
    _selectedDate = selectedDate;
    setState(() {
      //_updateDataRow();
    });

    _getByName(widget.name, _selectedDate);
  }

  Widget _monthButton() {
    return Center(
        child: ElevatedButton(
      child: Text(_yearMonthFormat.format(_selectedDate)),
      onPressed: () {
        _selectMonth();
      },
    ));
  }

  Future<void> _exportData() async {
    String name = _monthlyTimecard!.name;
    String date = DateFormat('yyyy_MM').format(_monthlyTimecard!.date);
    String fileName = '${name}_$date.csv';

    final header = _columnNames;
    final rows = _monthlyTimecard!.toCsvFormat();
    final csv = const ListToCsvConverter().convert([header, ...rows]);

    if (kIsWeb == true) {
      csvDownload(fileName: fileName, csv: csv, utf8BOM: true);
    }
  }

  void csvDownload(
      {required String fileName, required String csv, bool utf8BOM = false}) {
    if (!kIsWeb) return;
    html.AnchorElement anchorElement;
    if (utf8BOM) {
      //　Excelで開く用に日本語を含む場合はUTF-8 BOMにする措置
      // ref. https://github.com/close2/csv/issues/41#issuecomment-899038353
      final base64CsvBytes = Encoder.toUtf8WithBOM(csv);
      anchorElement = html.AnchorElement(
        href: 'data:text/plain;charset=utf-8;base64,$base64CsvBytes',
      );
    } else {
      anchorElement = html.AnchorElement(
        href: 'data:text/plain;charset=utf-8,$csv',
      );
    }
    anchorElement
      ..setAttribute('download', fileName)
      ..click();
  }

  Widget _commnadButtons() {
    TextStyle? buttonTextStyle = TextStyle(
        color: Colors.white,
        fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize);

    double buttonHeight = 50;
    //double spaceMulti = 0.025;
    double buttonWidthMulti = 0.3;

    return LayoutBuilder(
        builder: (context, constraints) => Wrap(
                runAlignment: WrapAlignment.center,
                //spacing: constraints.maxWidth * spaceMulti,
                children: [
                  //if (widget.clockIn)
                  SizedBox(
                      width: constraints.maxWidth * buttonWidthMulti,
                      height: buttonHeight,
                      child: ElevatedButton(
                          onPressed: _exportData,
                          child: Text('CSV出力', style: buttonTextStyle)))
                ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: MyAppBar(title: widget.title).appBar(context),
        body: SingleChildScrollView(
            child: Padding(
                padding: Constants.allPadding,
                child: Center(
                    child: Column(children: [
                  SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.05,
                      child: _monthButton()),
                  SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: Padding(
                        padding: Constants.topBottomPadding,
                        child: LayoutBuilder(
                            builder: (context, constraints) => DataTableView(
                                //columns: _createDataColumnList(),
                                firstHeaderCell: _createFirstHeaderCell(),
                                headers: _createHeaders(),
                                rows: _createRows(),
                                // 列数から幅を割り出す。固定比率のままだと
                                // 編集列を足したときに画面からはみ出す。
                                firstColumnWidth:
                                    max(110, constraints.maxWidth / _columnCount),
                                defaultsColumnWidth:
                                    max(110, constraints.maxWidth / _columnCount),
                                headerHeight: 60,
                                defaultsRowHeight: 60,
                                isLoading: _isLoading)),
                      )),
                  _commnadButtons(),
                ])))));
  }
}
