import 'package:flutter/material.dart';

import '../../../services/attendance_service.dart';
import '../../../services/gas_client.dart';

/// この端末を共有端末にするか、特定の人の端末にするかを切り替えるダイアログ。
///
/// 名義のある端末はその人のタイムカードをパスワードなしで開けるため、
/// 変更にはその人のパスワードによる本人確認が要る。
class DeviceSettingsDialog extends StatefulWidget {
  final AttendanceService attendanceService;
  final List<String> userNames;

  /// 現在の名義。共有端末なら null。
  final String? currentUser;

  const DeviceSettingsDialog({
    super.key,
    required this.attendanceService,
    required this.userNames,
    required this.currentUser,
  });

  @override
  State<DeviceSettingsDialog> createState() => _DeviceSettingsDialogState();
}

class _DeviceSettingsDialogState extends State<DeviceSettingsDialog> {
  final TextEditingController _passwordController = TextEditingController();

  late bool _shared;
  String? _selectedName;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _shared = widget.currentUser == null;

    // DropdownButtonFormField は items に無い値を渡すとアサーションで落ちる。
    // 名義がシートから消えている場合があるので、候補に含まれるか確かめる。
    final String? current = widget.currentUser;
    _selectedName = (current != null && widget.userNames.contains(current))
        ? current
        : (widget.userNames.isEmpty ? null : widget.userNames.first);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _selectedName == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final bool ok = await widget.attendanceService.updateDeviceOwner(
        _selectedName!,
        _passwordController.text,
        shared: _shared,
      );

      if (!mounted) {
        return;
      }

      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorMessage = 'パスワードが違います';
      });
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

  String get _currentLabel {
    final String? user = widget.currentUser;
    return user == null ? '共有端末' : '$user の端末';
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;

    return AlertDialog(
      title: const Text('端末の設定'),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('現在: $_currentLabel', style: style),
              ),
              CheckboxListTile(
                value: _shared,
                onChanged: _isSubmitting
                    ? null
                    : (v) => setState(() => _shared = v ?? false),
                title: const Text('共有端末として使う'),
                subtitle: const Text('タイムカードの閲覧に毎回パスワードが必要になります。'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              DropdownButtonFormField<String>(
                value: _selectedName,
                decoration: InputDecoration(
                  labelText: _shared ? '名前（確認用）' : 'この端末の持ち主',
                ),
                items: widget.userNames
                    .map((name) =>
                        DropdownMenuItem(value: name, child: Text(name)))
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _selectedName = value),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                enabled: !_isSubmitting,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'パスワード'),
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
              : const Text('保存'),
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
