import 'package:flutter/material.dart';

import '../../application/constants.dart';
import '../../services/attendance_service.dart';
import '../../services/gas_client.dart';
import '../components/my_app_bar.dart';

/// 管理者設定画面。
///
/// AdminLoginDialog での本人確認を経て開く。保存のたびに同じ管理者の
/// パスワードを送る（サーバー側がその場で isAdmin_ を確認するため、
/// セッションのようなものは持たない）。
class SettingsPage extends StatefulWidget {
  final AttendanceService attendanceService;
  final String adminName;
  final String adminPassword;
  final Map<String, dynamic> initialSettings;

  const SettingsPage({
    super.key,
    required this.attendanceService,
    required this.adminName,
    required this.adminPassword,
    required this.initialSettings,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _workHoursController;
  late final TextEditingController _minPasswordLengthController;
  late final TextEditingController _sessionHoursController;
  late final TextEditingController _calendarIdController;
  late final TextEditingController _paidHolidayDaysController;
  late final TextEditingController _grantMonthController;
  late final TextEditingController _grantDayController;
  late final TextEditingController _expirationYearsController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic> s = widget.initialSettings;

    _workHoursController =
        TextEditingController(text: _numStr(s['standardWorkHoursPerDay'], 8));
    _minPasswordLengthController =
        TextEditingController(text: _numStr(s['minPasswordLength'], 6, fractionDigits: 0));
    // 保存値は秒。画面では時間で見せる方が分かりやすい。
    final double ttlSeconds = _numOr(s['sessionTtlSeconds'], 21600);
    _sessionHoursController =
        TextEditingController(text: (ttlSeconds / 3600).toStringAsFixed(1));
    _calendarIdController = TextEditingController(
        text: (s['companyHolidayCalendarId'] ?? '').toString());
    _paidHolidayDaysController =
        TextEditingController(text: _numStr(s['paidHolidayGrantDays'], 10));
    _grantMonthController =
        TextEditingController(text: _numStr(s['paidHolidayGrantMonth'], 9, fractionDigits: 0));
    _grantDayController =
        TextEditingController(text: _numStr(s['paidHolidayGrantDay'], 1, fractionDigits: 0));
    _expirationYearsController = TextEditingController(
        text: _numStr(s['paidHolidayExpirationYears'], 2, fractionDigits: 0));
  }

  double _numOr(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }

  String _numStr(dynamic value, double fallback, {int fractionDigits = 1}) {
    final double n = _numOr(value, fallback);
    return fractionDigits == 0
        ? n.toStringAsFixed(0)
        : (n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toString());
  }

  @override
  void dispose() {
    _workHoursController.dispose();
    _minPasswordLengthController.dispose();
    _sessionHoursController.dispose();
    _calendarIdController.dispose();
    _paidHolidayDaysController.dispose();
    _grantMonthController.dispose();
    _grantDayController.dispose();
    _expirationYearsController.dispose();
    super.dispose();
  }

  /// 数値として読めない入力があれば、その項目名を返す。全て読めれば null。
  String? _firstInvalidField() {
    final fields = <String, TextEditingController>{
      '所定労働時間': _workHoursController,
      'パスワード最低文字数': _minPasswordLengthController,
      'セッション有効期限': _sessionHoursController,
      '有休の年間付与日数': _paidHolidayDaysController,
      '有休の付与月': _grantMonthController,
      '有休の付与日': _grantDayController,
      '有休の失効年数': _expirationYearsController,
    };

    for (final entry in fields.entries) {
      if (double.tryParse(entry.value.text) == null) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final String? invalidField = _firstInvalidField();
    if (invalidField != null) {
      setState(() => _errorMessage = '$invalidFieldは数値で入力してください');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final Map<String, dynamic> settings = {
      'standardWorkHoursPerDay': double.parse(_workHoursController.text),
      'minPasswordLength': double.parse(_minPasswordLengthController.text),
      'sessionTtlSeconds': double.parse(_sessionHoursController.text) * 3600,
      'companyHolidayCalendarId': _calendarIdController.text.trim(),
      'paidHolidayGrantDays': double.parse(_paidHolidayDaysController.text),
      'paidHolidayGrantMonth': double.parse(_grantMonthController.text),
      'paidHolidayGrantDay': double.parse(_grantDayController.text),
      'paidHolidayExpirationYears':
          double.parse(_expirationYearsController.text),
    };

    try {
      final Map<String, dynamic> saved =
          await widget.attendanceService.updateSettings(
        widget.adminName,
        widget.adminPassword,
        settings,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      // サーバーで丸められた値（クランプなど）を画面にも反映する。
      setState(() {
        final Map<String, dynamic> s = saved;
        _workHoursController.text = _numStr(s['standardWorkHoursPerDay'], 8);
        _minPasswordLengthController.text =
            _numStr(s['minPasswordLength'], 6, fractionDigits: 0);
        _sessionHoursController.text =
            (_numOr(s['sessionTtlSeconds'], 21600) / 3600).toStringAsFixed(1);
        _calendarIdController.text =
            (s['companyHolidayCalendarId'] ?? '').toString();
        _paidHolidayDaysController.text =
            _numStr(s['paidHolidayGrantDays'], 10);
        _grantMonthController.text =
            _numStr(s['paidHolidayGrantMonth'], 9, fractionDigits: 0);
        _grantDayController.text =
            _numStr(s['paidHolidayGrantDay'], 1, fractionDigits: 0);
        _expirationYearsController.text =
            _numStr(s['paidHolidayExpirationYears'], 2, fractionDigits: 0);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
    } on GasException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = '通信に失敗しました';
      });
    }
  }

  Widget _numberField(String label, TextEditingController controller,
      {String? helperText}) {
    return Padding(
      padding: Constants.topBottomPadding,
      child: TextField(
        controller: controller,
        enabled: !_isSaving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, helperText: helperText),
        maxLines: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppBar(title: '設定').appBar(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: Constants.allPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
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
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4),
                    child: Text('勤怠ルール',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _numberField('所定労働時間（時間/日）', _workHoursController,
                      helperText: '残業時間の算出に使う'),
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 4),
                    child: Text('認証・セキュリティ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _numberField('パスワード最低文字数', _minPasswordLengthController),
                  _numberField('本人確認セッションの有効期限（時間）', _sessionHoursController,
                      helperText: '上限6時間'),
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 4),
                    child: Text('カレンダー',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: Constants.topBottomPadding,
                    child: TextField(
                      controller: _calendarIdController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: '会社の休日カレンダーID',
                        hintText: '例: xxxx@group.calendar.google.com',
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 4),
                    child: Text('有給休暇',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _numberField('年間付与日数（全社一律）', _paidHolidayDaysController),
                  Padding(
                    padding: Constants.topBottomPadding,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _grantMonthController,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: '付与月'),
                            maxLines: 1,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('/'),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _grantDayController,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: '付与日'),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _numberField('失効までの年数', _expirationYearsController,
                      helperText: '付与からこの年数で失効（未実装: 現在は設定値の保存のみ）'),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('保存する'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
