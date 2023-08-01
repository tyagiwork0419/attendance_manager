import 'package:flutter/material.dart';
import 'package:flutter_expandable_table/flutter_expandable_table.dart';

import '../../application/constants.dart';

class DataTableView extends StatefulWidget {
  final ScrollController? scrollController;
  //final List<DataColumn> columns;
  final ExpandableTableCell firstHeaderCell;
  final List<ExpandableTableHeader> headers;
  //final List<String> columnLabels;
  //final List<DataRow>? rows;
  final List<ExpandableTableRow> rows;
  //final MonthlyTimecard _monthlyTimecard;
  final bool? isLoading;

  DataTableView(
      {super.key,
      ScrollController? scrollController,
      required this.firstHeaderCell,
      required this.headers,
      required this.rows,
      bool? isLoading})
      : scrollController = scrollController ?? ScrollController(),
        isLoading = isLoading ?? false;

  @override
  State<DataTableView> createState() => _DataTableViewState();

  static buildCell(Widget content, {Color? color}) {
    return ExpandableTableCell(
      child: DefaultCellCard(
        color: color,
        child: Center(child: content),
      ),
    );
  }

  static ExpandableTableCell buildFirstRowCell({Widget? child, Color? color}) {
    return ExpandableTableCell(
      builder: (context, details) => DefaultCellCard(
        color: color,
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Row(
            children: [
              SizedBox(
                width: 24 * details.row!.address.length.toDouble(),
                child: details.row?.children != null
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedRotation(
                          duration: const Duration(milliseconds: 500),
                          turns:
                              details.row?.childrenExpanded == true ? 0.25 : 0,
                          child: const Icon(
                            Icons.keyboard_arrow_right,
                            color: Colors.black,
                          ),
                        ),
                      )
                    : null,
              ),
              if (child != null) child,
            ],
          ),
        ),
      ),
    );
  }
}

class _DataTableViewState extends State<DataTableView> {
  final ScrollController scrollControllerX = ScrollController();

  late ExpandableTableController controller;

  @override
  void initState() {
    super.initState();
    controller = ExpandableTableController(
      firstHeaderCell: widget.firstHeaderCell,
      headers: widget.headers,
      rows: [],
      headerHeight: 60,
      defaultsRowHeight: 60,
      defaultsColumnWidth: 200,
      firstColumnWidth: 200,
    );
  }

  Widget _loading() {
    return const Stack(fit: StackFit.expand, children: [
      ColoredBox(
        color: Colors.black26,
      ),
      Center(child: CircularProgressIndicator()),
    ]);
  }

  ExpandableTable _buildExpandableTable() {
    controller.rows = widget.rows;
    return ExpandableTable(controller: controller);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, alignment: Alignment.center, children: [
      Container(
          decoration: BoxDecoration(border: Border.all()),
          child: LayoutBuilder(
              builder: ((context, constraints) => Scrollbar(
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
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth,
                                      minHeight: constraints.minHeight,
                                      maxHeight: constraints.maxHeight),
                                  child: _buildExpandableTable())))))))),
      if (widget.isLoading!) _loading(),
    ]);
  }
}

class DefaultCellCard extends StatelessWidget {
  final Widget child;
  final Color? color;

  const DefaultCellCard({
    Key? key,
    required this.child,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      //color: primaryColor,
      color: color,
      margin: const EdgeInsets.all(1),
      child: child,
    );
  }
}
