import 'package:flutter/material.dart';

import '../../application/constants.dart';

/// AppBar のメニュー項目。
enum AppBarMenu { changePassword }

class MyAppBar {
  final String title;
  final String? version;

  /// メニューを出す場合に指定する。null ならメニュー自体を表示しない。
  final void Function(AppBarMenu item)? onMenuSelected;

  const MyAppBar({required this.title, this.version, this.onMenuSelected});

  AppBar appBar(BuildContext context) {
    return AppBar(
      // Here we take the value from the MyHomePage object that was created by
      // the App.build method, and use it to set our appbar title.
      title: Text(title),
      actions: [
        if (version != null)
          Padding(
              padding: EdgeInsets.only(right: onMenuSelected == null ? 30 : 8),
              child: Align(
                  alignment: Alignment.centerRight,
                  child: _version(context, version!))),
        if (onMenuSelected != null)
          PopupMenuButton<AppBarMenu>(
            icon: const Icon(Icons.more_vert),
            onSelected: onMenuSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: AppBarMenu.changePassword,
                child: Text('パスワードの変更'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _version(BuildContext context, String version) {
    TextStyle? versionTextStyle = Constants.getVersionTextStyle(context);
    return Text('version: $version', style: versionTextStyle);
  }
}
