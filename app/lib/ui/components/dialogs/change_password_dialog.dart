import 'package:flutter/material.dart';

import '../../../services/attendance_service.dart';
import '../../../services/gas_client.dart';

/// パスワード変更ダイアログ。
///
/// 現在のパスワードを知っていることが変更の条件で、照合は GAS 側が行う。
class ChangePasswordDialog extends StatefulWidget {
  final AttendanceService attendanceService;
  final List<String> userNames;

  /// 端末が個人名義なら、その名前を初期選択にする。
  final String? initialName;

  const ChangePasswordDialog({
    super.key,
    required this.attendanceService,
    required this.userNames,
    this.initialName,
  });

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  String? _selectedName;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // DropdownButtonFormField は items に無い value を渡すとアサーションで落ちる。
    // 端末の名義がシートから消えている場合があるので、候補に含まれるか確かめる。
    final String? initial = widget.initialName;
    _selectedName = (initial != null && widget.userNames.contains(initial))
        ? initial
        : (widget.userNames.isEmpty ? null : widget.userNames.first);
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _selectedName == null) {
      return;
    }

    // 確認欄との一致だけはサーバーに問い合わせるまでもないので手前で弾く。
    if (_newController.text != _confirmController.text) {
      setState(() => _errorMessage = '新しいパスワードが一致しません');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.attendanceService.changePassword(
        _selectedName!,
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on GasException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = '通信に失敗しました';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('パスワードの変更'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _selectedName = value),
              ),
              TextField(
                controller: _currentController,
                obscureText: true,
                enabled: !_isSubmitting,
                autofocus: true,
                decoration: const InputDecoration(labelText: '現在のパスワード'),
                maxLines: 1,
              ),
              TextField(
                controller: _newController,
                obscureText: true,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: '新しいパスワード',
                  helperText: '6文字以上',
                ),
                maxLines: 1,
              ),
              TextField(
                controller: _confirmController,
                obscureText: true,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(labelText: '新しいパスワード（確認）'),
                maxLines: 1,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('変更'),
        ),
        ElevatedButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
      ],
    );
  }
}
