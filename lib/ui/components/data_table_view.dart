import 'package:flutter/material.dart';

class DataTableView extends StatefulWidget {
  final ScrollController? scrollController;
  final List<DataRow>? dataRowList;
  final bool? isLoading;

  DataTableView(
      {super.key,
      ScrollController? scrollController,
      List<DataRow>? dataRowList,
      bool? isLoading})
      //scrollController ??= ScrollController();
      : scrollController = scrollController ?? ScrollController(),
        dataRowList = dataRowList ?? <DataRow>[],
        isLoading = isLoading ?? false;

  @override
  State<DataTableView> createState() => _DataTableViewState();
}

class _DataTableViewState extends State<DataTableView> {
  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(border: Border.all(width: 1)),
        child: SingleChildScrollView(
            controller: widget.scrollController,
                child: DataTable(
                    border: TableBorder.all(),
                    headingRowColor: MaterialStateColor.resolveWith(
                        (states) => const Color.fromARGB(255, 218, 218, 218)),
                    columns: const [
                      DataColumn(label: Text('名前')),
                      //DataColumn(label: Text('日付')),
                      DataColumn(label: Text('時刻')),
                      DataColumn(label: Text('種類')),
                      DataColumn(label: Text('削除')),
                    ],
                    rows: widget.dataRowList!)));
  }
}
