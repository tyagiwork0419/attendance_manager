import 'package:flutter/material.dart';

class Constants {
  //const Constants();

  static const String version = '0.0.37';

  /// GAS Web アプリのエンドポイント。
  ///
  /// Web ビルドの成果物はすべてブラウザに配信されるため、ここには秘密情報を
  /// 置けない。認証情報は GAS 側（所有者権限で実行）が保持し、クライアントは
  /// ログインで得たセッショントークンのみを扱う。
  /// デプロイ手順は gas/README.md を参照。
  static const String webAppUrl = String.fromEnvironment(
    'GAS_WEB_APP_URL',
    defaultValue: 'https://script.google.com/macros/s/AKfycbzy4_kA6lUQNC2lGSVi8eCNp1kDx4Tpwpg6kSUVvLY6pB68pYAxaT45exapgXdAiTW6/exec',
  );

  static const double paddingMiddium = 10;
  static const String locale = 'ja';

  /// 1日の所定労働時間。これを超えた分を残業として集計する。
  /// 就業規則が変わったらここを直す。
  static const double standardWorkHoursPerDay = 8;

  static const EdgeInsets topBottomPadding = EdgeInsets.fromLTRB(
      0, Constants.paddingMiddium, 0, Constants.paddingMiddium);
  static const EdgeInsets allPadding = EdgeInsets.all(Constants.paddingMiddium);
  static const Duration wait100Milliseconds = Duration(milliseconds: 100);

  static const Color yellow = Color.fromARGB(255, 243, 236, 143);
  static const Color green = Color.fromARGB(255, 210, 255, 212);
  static const Color red = Color.fromARGB(255, 255, 213, 227);
  static const Color gray = Color.fromARGB(255, 218, 218, 218);
  static const Color brown = Color.fromARGB(255, 202, 150, 107);

  static TextStyle getVersionTextStyle(BuildContext context) {
    return TextStyle(
        color: Colors.white,
        fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize);
  }

  static TextStyle getButtonTextStyle(BuildContext context) {
    return TextStyle(
        color: Colors.white,
        fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize);
  }
}
