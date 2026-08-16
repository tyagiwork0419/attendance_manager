import 'dart:convert';
import 'package:http/http.dart' as http;

import 'device_session.dart';

/// GAS からのエラー応答。
class GasException implements Exception {
  final String message;

  /// GAS が返すエラー種別。`invalid_credentials` / `unauthorized` など。
  final String? code;

  GasException(this.message, {this.code});

  /// 本人確認が必要。パスワード入力を促す。
  bool get isUnauthorized => code == 'unauthorized';

  /// 端末が未登録または失効している。端末登録からやり直す必要がある。
  bool get isDeviceUnauthorized => code == 'device_unauthorized';

  @override
  String toString() => message;
}

/// GAS Web アプリとの通信を担う。
///
/// クライアントは認証情報を一切保持しない。GAS 側が所有者権限で動作するため、
/// OAuth のやりとりは不要で、ログインで得たセッショントークンのみを添付する。
class GasClient {
  final String _webAppUrl;
  final DeviceSession _device;

  /// 本人確認用の短命セッション。他人のタイムカードを開くときだけ使う。
  String? _sessionToken;

  GasClient(this._webAppUrl, this._device);

  bool get isAuthenticated => _sessionToken != null;

  bool get isDeviceRegistered => _device.isRegistered;

  /// この端末の名義。共有端末なら null。
  String? get deviceUser => _device.user;

  void clearSession() {
    _sessionToken = null;
  }

  /// CORS プリフライト(OPTIONS)を避けるため text/plain で送る。
  /// GAS Web アプリは OPTIONS を処理できないため application/json は使えない。
  static const Map<String, String> _headers = {
    'Content-Type': 'text/plain;charset=utf-8',
  };

  Future<dynamic> _send(Map<String, dynamic> payload) async {
    final http.Response response = await http.post(
      Uri.parse(_webAppUrl),
      headers: _headers,
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw GasException('通信に失敗しました (HTTP ${response.statusCode})');
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // GAS が HTML のエラーページを返した場合など。
      throw GasException('サーバーの応答を解釈できませんでした');
    }

    if (decoded['ok'] != true) {
      throw GasException(
        decoded['error']?.toString() ?? '不明なエラー',
        code: decoded['code']?.toString(),
      );
    }

    return decoded['result'];
  }

  /// ログイン画面に表示する名前の一覧。パスワード情報は含まれない。
  Future<List<String>> getUserNames() async {
    final dynamic result = await _send({'action': 'getUsers'});
    if (result is! List) {
      return const [];
    }
    return result.map((dynamic e) => e.toString()).toList();
  }

  /// 認証は GAS 側で行う。成功時のみセッショントークンを保持する。
  ///
  /// パスワードが違う場合は false を返す。通信エラー等は [GasException] を投げる。
  Future<bool> login(String name, String password) async {
    try {
      final dynamic result = await _send({
        'action': 'login',
        'name': name,
        'password': password,
      });
      _sessionToken = (result as Map<String, dynamic>)['token'] as String;
      return true;
    } on GasException catch (e) {
      if (e.code == 'invalid_credentials') {
        return false;
      }
      rethrow;
    }
  }

  /// この端末を登録する。以後は端末トークンだけでデータ操作ができる。
  ///
  /// [shared] を true にすると共有端末として登録し、名義を持たせない。
  /// その場合タイムカードの閲覧には都度パスワードが必要になる。
  ///
  /// パスワードが違う場合は false を返す。
  Future<bool> registerDevice(
    String name,
    String password, {
    required String label,
    required bool shared,
  }) async {
    try {
      final dynamic result = await _send({
        'action': 'registerDevice',
        'name': name,
        'password': password,
        'label': label,
        'shared': shared,
      });

      final Map<String, dynamic> map = result as Map<String, dynamic>;
      _device.save(map['token'] as String, map['user'] as String?);
      return true;
    } on GasException catch (e) {
      if (e.code == 'invalid_credentials') {
        return false;
      }
      rethrow;
    }
  }

  /// パスワードを変更する。現在のパスワードによる本人確認を伴う。
  ///
  /// 現在のパスワードが違う場合や新しいパスワードが条件を満たさない場合は
  /// [GasException] を投げる。呼び出し側でメッセージをそのまま表示できる。
  Future<void> changePassword(
    String name, {
    required String currentPassword,
    required String newPassword,
  }) async {
    await _send({
      'action': 'changePassword',
      'name': name,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'deviceToken': _device.token,
    });
  }

  /// 端末登録を解除する。サーバー側で revoke された場合にも使う。
  void clearDevice() {
    _device.clear();
    _sessionToken = null;
  }

  /// データ操作を呼び出す。戻り値は既存の呼び出し側に合わせて JSON 文字列。
  ///
  /// 端末が失効していた場合はローカルの登録も破棄する。そうしないと
  /// 使えないトークンを送り続けることになる。
  Future<String> post(String functionName, Object parameters) async {
    final Map<String, dynamic> payload = {
      'action': functionName,
      'parameters': parameters,
      'deviceToken': _device.token,
    };
    if (_sessionToken != null) {
      payload['token'] = _sessionToken;
    }

    try {
      final dynamic result = await _send(payload);
      return result is String ? result : json.encode(result);
    } on GasException catch (e) {
      if (e.isDeviceUnauthorized) {
        clearDevice();
      }
      rethrow;
    }
  }
}
