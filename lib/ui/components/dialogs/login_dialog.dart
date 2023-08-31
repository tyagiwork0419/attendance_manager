import 'package:flutter/material.dart';

class LoginDialog extends StatefulWidget {
  final String selectedName;
  final String selectedPassword;
  const LoginDialog({
    super.key,
    required this.selectedName,
    required this.selectedPassword,
  });

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final TextStyle _errorStyle = const TextStyle(color: Colors.red);
  bool _error = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text('パスワードを入力してください'),
        content: SizedBox(
            height: 100,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              if (_error) Text('パスワードが違います', style: _errorStyle),
              Row(children: [const Text('名前: '), Text(widget.selectedName)]),
              SizedBox(
                  width: 300,
                  height: 50,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.visiblePassword,
                    decoration: const InputDecoration(labelText: 'パスワード'),
                    maxLines: 1,
                  ))
            ])),
        actions: [
          ElevatedButton(
            child: const Text('決定'),
            onPressed: () {
              bool result = _controller.text == widget.selectedPassword;
              if (result) {
                Navigator.of(context).pop(result);
              } else {
                setState(() {
                  _error = true;
                });
              }
            },
          ),
          ElevatedButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop(null);
              }),
        ]);
  }
}
