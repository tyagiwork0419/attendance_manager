import 'package:flutter/material.dart';

import '../../application/constants.dart';

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
  final ScrollController scrollControllerX = ScrollController();
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
          child: LayoutBuilder(
              builder: ((context, constraints) => //ListView(children: [
                  Scrollbar(
                      thumbVisibility: true,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      controller: scrollControllerX,
                      child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: scrollControllerX,
                          child: Scrollbar(
                              thumbVisibility: true,
                              controller: widget.scrollController,
                              child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  controller: widget.scrollController,
                                  child: Container(
                                      //width: constraints.maxWidth,
                                      constraints: BoxConstraints(
                                          minWidth: constraints.maxWidth),
                                      child: DataTable(
                                          headingRowHeight: 60,
                                          dataRowMaxHeight: 60,
                                          dataRowMinHeight: 60,
                                          border: TableBorder.all(),
                                          headingRowColor:
                                              MaterialStateColor.resolveWith(
                                                  (states) => Constants.gray),
                                          columns: widget.columns,
                                          rows: widget.rows!))))))))),
      if (widget.isLoading!) _loading(),
    ]);
  }
}
