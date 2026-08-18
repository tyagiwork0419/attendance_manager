import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

/// 時刻ピッカーを午前・午後で操作するための日本語ローカライズ。
///
/// showTimePicker のダイヤル形式はロケールの時刻表記から決まる。
/// ja の標準表記は 24 時間制 (H:mm) なので、既定では 0〜23 のダイヤルになる。
///
/// MediaQuery の alwaysUse24HourFormat では切り替えられない。あれは true の
/// ときに 24 時間制を強制するもので、false はロケール標準に従うという意味しか
/// 持たないため、ja では結局 24 時間制のままになる。
///
/// そこで [timeOfDayFormatRaw] だけを差し替える。他の文言は ja のものを
/// そのまま受け継ぐので、画面は日本語のまま AM / PM で操作できる
/// （ja の午前・午後の表記は 'AM' / 'PM'）。
class JaAmPmMaterialLocalizations extends MaterialLocalizationJa {
  const JaAmPmMaterialLocalizations({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  TimeOfDayFormat get timeOfDayFormatRaw => TimeOfDayFormat.h_colon_mm_space_a;

  /// 時刻ピッカーを包むときに Localizations.override へ渡す。
  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _JaAmPmMaterialLocalizationsDelegate();
}

class _JaAmPmMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _JaAmPmMaterialLocalizationsDelegate();

  static const String _localeName = 'ja';

  @override
  bool isSupported(Locale locale) => locale.languageCode == _localeName;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    // 日付データの読み込みは本家の delegate に任せる。
    // 自前で intl を初期化すると、Flutter 側の手順と二重管理になる。
    GlobalMaterialLocalizations.delegate.load(locale);

    // 書式は本家と同じ名前付きコンストラクタで作る。
    // パターン文字列を書き写すと Flutter 側の変更に追随できなくなる。
    return SynchronousFuture<MaterialLocalizations>(
      JaAmPmMaterialLocalizations(
        fullYearFormat: intl.DateFormat.y(_localeName),
        compactDateFormat: intl.DateFormat.yMd(_localeName),
        shortDateFormat: intl.DateFormat.yMMMd(_localeName),
        mediumDateFormat: intl.DateFormat.MMMEd(_localeName),
        longDateFormat: intl.DateFormat.yMMMMEEEEd(_localeName),
        yearMonthFormat: intl.DateFormat.yMMMM(_localeName),
        shortMonthDayFormat: intl.DateFormat.MMMd(_localeName),
        decimalFormat: intl.NumberFormat.decimalPattern(_localeName),
        twoDigitZeroPaddedFormat: intl.NumberFormat('00', _localeName),
      ),
    );
  }

  @override
  bool shouldReload(_JaAmPmMaterialLocalizationsDelegate old) => false;
}
