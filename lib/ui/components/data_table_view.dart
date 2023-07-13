import 'package:flutter/material.dart';

class DataTableView extends StatefulWidget {
  final ScrollController? scrollController;
  final List<DataColumn> dataColumnList;
  final List<DataRow>? dataRowList;
  final bool? isLoading;

  DataTableView(
      {super.key,
      ScrollController? scrollController,
      required this.dataColumnList,
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
        decoration: BoxDecoration(border: Border.all()),
        child: SingleChildScrollView(
            controller: widget.scrollController,
            child: DataTable(
                headingRowHeight: 60,
                dataRowMaxHeight: 60,
                dataRowMinHeight: 60,
                border: TableBorder.all(),
                headingRowColor: MaterialStateColor.resolveWith(
                    (states) => const Color.fromARGB(255, 218, 218, 218)),
                columns: widget.dataColumnList,
                rows: widget.dataRowList!)));
  }
}
