import 'package:flutter/material.dart';

import '../../application/constants.dart';
import '../../services/attendance_service.dart';
import '../../services/gas_client.dart';
import '../components/my_app_bar.dart';

/// 端末登録画面。
///
/// 未登録の端末で起動したときだけ表示される。ここで一度登録すれば
/// トークンが localStorage に保存され、以後は打刻のたびのログインが不要になる。
class DeviceRegistrationPage extends StatefulWidget {
  final AttendanceService attendanceService;
  final VoidCallback onRegistered;

  const DeviceRegistrationPage({
    super.key,
    required this.attendanceService,
    required this.onRegistered,
  });

  @override
  State<DeviceRegistrationPage> createState() => _DeviceRegistrationPageState();
}

class _DeviceRegistrationPageState extends State<DeviceRegistrationPage> {
  final TextEditingController _passwordController = TextEditingController();

  List<String> _userNames = [];
  String? _selectedName;
  bool _shared = false;

  bool _isLoadingNames = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserNames();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserNames() async {
    try {
      final List<String> names = await widget.attendanceService.getUserNames();
      if (!mounted) {
        return;
      }
      setState(() {
        _userNames = names;
        _selectedName = names.isEmpty ? null : names.first;
        _isLoadingNames = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingNames = false;
        _errorMessage = '名前の取得に失敗しました: $e';
      });
    }
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
      final bool ok = await widget.attendanceService.registerDevice(
        _selectedName!,
        _passwordController.text,
        label: '',
        shared: _shared,
      );

      if (!mounted) {
        return;
      }

      if (ok) {
        widget.onRegistered();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppBar(title: '端末登録', version: Constants.version)
          .appBar(context),
      body: Center(
        child: SingleChildScrollView(
          padding: Constants.allPadding,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _isLoadingNames
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildForm(context),
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildForm(BuildContext context) {
    return [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'この端末を登録します。\n登録は最初の1回だけで、次回からはそのまま打刻できます。',
          style: TextStyle(fontSize: 16),
        ),
      ),
      if (_errorMessage != null)
        Padding(
          padding: Constants.topBottomPadding,
          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      Padding(
        padding: Constants.topBottomPadding,
        child: DropdownButtonFormField<String>(
          value: _selectedName,
          decoration: const InputDecoration(labelText: '名前'),
          items: _userNames
              .map((name) => DropdownMenuItem(value: name, child: Text(name)))
              .toList(),
          onChanged: _isSubmitting
              ? null
              : (value) => setState(() => _selectedName = value),
        ),
      ),
      Padding(
        padding: Constants.topBottomPadding,
        child: TextField(
          controller: _passwordController,
          keyboardType: TextInputType.visiblePassword,
          obscureText: true,
          enabled: !_isSubmitting,
          decoration: const InputDecoration(labelText: 'パスワード'),
          maxLines: 1,
          onSubmitted: (_) => _submit(),
        ),
      ),
      CheckboxListTile(
        value: _shared,
        onChanged:
            _isSubmitting ? null : (v) => setState(() => _shared = v ?? false),
        title: const Text('共有端末として登録する'),
        subtitle: const Text('全員で使う端末の場合はチェック。\n'
            'タイムカードの閲覧に毎回パスワードが必要になります。'),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('登録する'),
          ),
        ),
      ),
    ];
  }
}
