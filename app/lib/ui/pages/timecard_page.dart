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
import '../../models/timecard_data.dart';
import '../../services/attendance_service.dart';
import '../components/data_table_view.dart';
import '../components/dialogs/error_dialog.dart';
import '../components/my_app_bar.dart';
import 'my_home_page.dart';
import 'summary_page.dart';

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

  /// 端末が失効していた場合に呼ばれる。編集ボタンから開く出退勤入力画面に
  /// そのまま引き継ぐ。
  final VoidCallback? onDeviceRevoked;

  const TimecardPage(
      {super.key,
      required this.service,
      //required this.title,
      required this.name,
      required this.dateTime,
      required this.initialData,
      this.onDeviceRevoked})
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

  /// データのある年。月選択で選べる範囲に使う。
  List<int> _availableYears = [];

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

    _loadAvailableYears();
  }

  /// 月選択の範囲を決めるために取る。失敗しても表の表示は妨げない。
  Future<void> _loadAvailableYears() async {
    try {
      final List<int> years = await _service.getAvailableYears();
      if (!mounted) {
        return;
      }
      setState(() {
        _availableYears = years;
      });
    } catch (e) {
      debugPrint('listYears failed: $e');
    }
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

  /// その日の出退勤入力画面を開くボタン。
  ExpandableTableCell _createEditCell(DailyTimecard timecard, Color color) {
    return DataTableView.buildCell(
      IconButton(
        icon: const Icon(Icons.edit),
        tooltip: 'この日の出退勤を編集',
        onPressed: _isLoading ? null : () => _openDayInput(timecard),
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

  /// その日の出退勤入力画面（ホーム画面と同じもの）を、打刻対象を
  /// このタイムカードの持ち主に固定して開く。
  ///
  /// ホーム画面と同じ出勤・退勤・有休ボタンと、その日の一覧（削除も可能）が
  /// 使えるため、時刻を手入力するより誤りにくい。戻ってきたら月のデータを
  /// 取り直して反映する。
  Future<void> _openDayInput(DailyTimecard timecard) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => MyHomePage(
                title: '出退勤の編集 ( $_name )',
                attendanceService: _service,
                onDeviceRevoked: widget.onDeviceRevoked ?? () {},
                initialDate: timecard.date,
                fixedName: _name)));

    if (!mounted) {
      return;
    }
    await _getByName(_name, _selectedDate);
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
    _monthlyTimecard = _service.createMonthlyTimecard(
        _name, _selectedDate.year, _selectedDate.month, dataList);
  }

  Future<void> _selectMonth() async {
    // 選べる範囲はデータのある年の全体。以前は前後1年に固定していたため、
    // それより古い記録に辿り着けなかった。
    final int firstYear =
        _availableYears.isEmpty ? _selectedDate.year - 1 : _availableYears.first;
    final int lastYear = _availableYears.isEmpty
        ? _selectedDate.year + 1
        // 表示中の年が一覧より新しいこともあるので、狭めないようにする。
        : max(_availableYears.last, _selectedDate.year);

    var selectedDate = await showMonthPicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(min(firstYear, _selectedDate.year), 1),
      lastDate: DateTime(lastYear, 12),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            child: Text(_yearMonthFormat.format(_selectedDate)),
            onPressed: () {
              _selectMonth();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _openSummary,
              child: const Text('集計データ'),
            ),
          ),
        ],
      ),
    );
  }

  void _openSummary() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SummaryPage(
                service: _service, name: _name, dateTime: _selectedDate)));
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
