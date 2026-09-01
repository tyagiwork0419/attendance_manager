import 'package:flutter/material.dart';

import '../../../services/attendance_service.dart';
import '../../../services/gas_client.dart';

/// 管理者設定画面を開く前の確認ダイアログ。
///
/// 管理者(role=admin)のパスワードでのみ通る。成功したら、そのまま設定
/// 画面の初期値として使えるよう、取得済みの設定と入力した名前・パスワード
/// を一緒に返す（保存時にもう一度同じ認証情報が要るため）。
class AdminLoginDialog extends StatefulWidget {
  final AttendanceService attendanceService;
  final List<String> userNames;
  final String? initialName;

  const AdminLoginDialog({
    super.key,
    required this.attendanceService,
    required this.userNames,
    this.initialName,
  });

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedName;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final String? initial = widget.initialName;
    _selectedName = (initial != null && widget.userNames.contains(initial))
        ? initial
        : (widget.userNames.isEmpty ? null : widget.userNames.first);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isVerifying || _selectedName == null) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> settings =
          await widget.attendanceService.getAdminSettings(
        _selectedName!,
        _passwordController.text,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop({
        'name': _selectedName!,
        'password': _passwordController.text,
        'settings': settings,
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
      title: const Text('管理者確認'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('設定の変更には管理者のパスワードが必要です。'),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red)),
              ),
            DropdownButtonFormField<String>(
              value: _selectedName,
              decoration: const InputDecoration(labelText: '名前'),
              items: widget.userNames
                  .map((name) =>
                      DropdownMenuItem(value: name, child: Text(name)))
                  .toList(),
              onChanged: _isVerifying
                  ? null
                  : (value) => setState(() => _selectedName = value),
            ),
            TextField(
              controller: _passwordController,
              keyboardType: TextInputType.visiblePassword,
              obscureText: true,
              enabled: !_isVerifying,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'パスワード'),
              maxLines: 1,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
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
          onPressed:
              _isVerifying ? null : () => Navigator.of(context).pop(null),
          child: const Text('キャンセル'),
        ),
      ],
    );
  }
}
