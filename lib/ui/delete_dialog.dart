import 'package:flutter/material.dart';

class DeleteDialog extends StatelessWidget {
  const DeleteDialog({super.key});

  @override
  Widget build(context) {
    return AlertDialog(title: const Text('データを削除しますか？'), actions: <Widget>[
      ElevatedButton(
          child: const Text('はい'),
          onPressed: () {
            //Navigator.pop(context);
            Navigator.of(context).pop(true);
          }),
      ElevatedButton(
          child: const Text('いいえ'),
          onPressed: () {
            Navigator.of(context).pop(false);
          })
    ]);
  }
}
