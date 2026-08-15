import 'package:flutter/material.dart';

import '../../../services/attendance_service.dart';
import '../../../services/gas_client.dart';

/// パスワード照合は GAS 側で行う。クライアントは正解のパスワードを持たない。
class LoginDialog extends StatefulWidget {
  final String selectedName;
  final AttendanceService attendanceService;

  const LoginDialog({
    super.key,
    required this.selectedName,
    required this.attendanceService,
  });

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final TextStyle _errorStyle = const TextStyle(color: Colors.red);
  final TextEditingController _controller = TextEditingController();

  String? _errorMessage;
  bool _isVerifying = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isVerifying) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final bool result = await widget.attendanceService.login(
        widget.selectedName,
        _controller.text,
      );

      if (!mounted) {
        return;
      }

      if (result) {
        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _isVerifying = false;
        _errorMessage = 'パスワードが違います';
      });
    } on GasException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isVerifying = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isVerifying = false;
        _errorMessage = '通信に失敗しました';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text('パスワードを入力してください'),
        content: SizedBox(
            height: 100,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              if (_errorMessage != null)
                Text(_errorMessage!, style: _errorStyle),
              Row(children: [const Text('名前: '), Text(widget.selectedName)]),
              SizedBox(
                  width: 300,
                  height: 50,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: true,
                    enabled: !_isVerifying,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'パスワード'),
                    maxLines: 1,
                    onSubmitted: (_) => _submit(),
                  ))
            ])),
        actions: [
          ElevatedButton(
            onPressed: _isVerifying ? null : _submit,
            child: _isVerifying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('決定'),
          ),
          ElevatedButton(
              onPressed: _isVerifying
                  ? null
                  : () {
                      Navigator.of(context).pop(null);
                    },
              child: const Text('キャンセル')),
        ]);
  }
}
