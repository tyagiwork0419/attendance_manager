import 'package:flutter/material.dart';
import 'package:nil/nil.dart';

class ErrorDialog extends StatelessWidget {
  final String? title;
  final String? content;
  const ErrorDialog({super.key, String? title, this.content})
      : title = title ?? 'エラー';

  static void showErrorDialog(BuildContext context, Object error) {
    debugPrint(error.toString());
    showDialog<void>(
        context: context,
        builder: (_) => ErrorDialog(title: '通信エラー', content: error.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text(title!),
        content: content != null ? Text(content!) : nil,
        actions: <Widget>[
          ElevatedButton(
              child: const Text('OK'),
              onPressed: () {
                //Navigator.pop(context);
                Navigator.of(context).pop(true);
              }),
        ]);
  }
}
