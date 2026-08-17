import 'package:flutter/material.dart';

/// 処理中の操作を受け付けないようにする全画面オーバーレイ。
///
/// 通信の完了を待つ間に同じボタンを何度も押せてしまうのを防ぐ。
class LoadingOverlay {
  /// [action] の実行中だけオーバーレイを表示する。
  ///
  /// 例外が出ても必ず閉じるので、呼び出し側はいつもどおり catch できる。
  static Future<T> during<T>(
    BuildContext context,
    Future<T> Function() action,
  ) async {
    // await をまたいで context を使うと無効になっていることがあるため、
    // Navigator は表示前に取っておく。
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        // 戻る操作でも閉じさせない。閉じられると処理中に操作できてしまう。
        onWillPop: () async => false,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      return await action();
    } finally {
      navigator.pop();
    }
  }
}
