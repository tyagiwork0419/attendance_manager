import 'package:flutter/material.dart';

class DataTableView extends StatefulWidget {
  final ScrollController? scrollController;
  final List<DataColumn> columns;
  final List<DataRow>? rows;
  final bool? isLoading;

  DataTableView(
      {super.key,
      ScrollController? scrollController,
      required this.columns,
      List<DataRow>? rows,
      bool? isLoading})
      : scrollController = scrollController ?? ScrollController(),
        rows = rows ?? <DataRow>[],
        isLoading = isLoading ?? false;

  @override
  State<DataTableView> createState() => _DataTableViewState();
}

class _DataTableViewState extends State<DataTableView> {
  Widget _loading() {
    return const Stack(fit: StackFit.expand, children: [
      ColoredBox(
        color: Colors.black26,
      ),
      Center(child: CircularProgressIndicator()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, alignment: Alignment.center, children: [
      Container(
          decoration: BoxDecoration(border: Border.all()),
          child: ListView(children: [
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: widget.scrollController,
                child: DataTable(
                    headingRowHeight: 60,
                    dataRowMaxHeight: 60,
                    dataRowMinHeight: 60,
                    border: TableBorder.all(),
                    headingRowColor: MaterialStateColor.resolveWith(
                        (states) => const Color.fromARGB(255, 218, 218, 218)),
                    columns: widget.columns,
                    rows: widget.rows!))
          ])),
      if (widget.isLoading!) _loading(),
    ]);
  }
}
