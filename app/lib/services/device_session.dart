import 'package:universal_html/html.dart' as html;

/// 端末トークンの永続化を担う。
///
/// localStorage に置くため、ブラウザを閉じても PC を再起動しても、
/// アプリを再デプロイしても保持される。利用者から見ると
/// 「最初の1回だけ端末登録すれば、以後はそのまま使える」動作になる。
///
/// 消えるのは、ブラウザのデータを削除したとき、別のブラウザや
/// シークレットウィンドウで開いたとき、明示的に登録解除したとき。
class DeviceSession {
  static const String _tokenKey = 'attendance.deviceToken';
  static const String _userKey = 'attendance.deviceUser';

  String? _token;

  /// この端末の名義。共有端末として登録した場合は null。
  String? _user;

  String? get token => _token;
  String? get user => _user;
  bool get isRegistered => _token != null;

  /// 起動時に一度だけ呼ぶ。
  void load() {
    final storage = html.window.localStorage;
    final String? token = storage[_tokenKey];
    _token = (token == null || token.isEmpty) ? null : token;

    final String? user = storage[_userKey];
    _user = (user == null || user.isEmpty) ? null : user;
  }

  void save(String token, String? user) {
    _token = token;
    _user = (user == null || user.isEmpty) ? null : user;

    final storage = html.window.localStorage;
    storage[_tokenKey] = token;
    if (_user == null) {
      storage.remove(_userKey);
    } else {
      storage[_userKey] = _user!;
    }
  }

  /// 端末登録を解除する。サーバー側で revoke された場合にも呼ばれる。
  void clear() {
    _token = null;
    _user = null;

    final storage = html.window.localStorage;
    storage.remove(_tokenKey);
    storage.remove(_userKey);
  }
}
