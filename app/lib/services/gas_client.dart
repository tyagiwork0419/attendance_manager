import 'dart:convert';
import 'package:http/http.dart' as http;

/// GAS からのエラー応答。
class GasException implements Exception {
  final String message;

  /// GAS が返すエラー種別。`invalid_credentials` / `unauthorized` など。
  final String? code;

  GasException(this.message, {this.code});

  bool get isUnauthorized => code == 'unauthorized';

  @override
  String toString() => message;
}

/// GAS Web アプリとの通信を担う。
///
/// クライアントは認証情報を一切保持しない。GAS 側が所有者権限で動作するため、
/// OAuth のやりとりは不要で、ログインで得たセッショントークンのみを添付する。
class GasClient {
  final String _webAppUrl;

  String? _sessionToken;

  GasClient(this._webAppUrl);

  bool get isAuthenticated => _sessionToken != null;

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

  /// データ操作を呼び出す。戻り値は既存の呼び出し側に合わせて JSON 文字列。
  Future<String> post(String functionName, Object parameters) async {
    final Map<String, dynamic> payload = {
      'action': functionName,
      'parameters': parameters,
    };
    if (_sessionToken != null) {
      payload['token'] = _sessionToken;
    }

    final dynamic result = await _send(payload);
    return result is String ? result : json.encode(result);
  }
}
