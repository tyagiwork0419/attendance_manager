import 'package:flutter/material.dart';

import '../../application/constants.dart';

class MyAppBar {
  final String title;
  final String version;

  const MyAppBar({required this.title, required this.version});

/*
  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Here we take the value from the MyHomePage object that was created by
      // the App.build method, and use it to set our appbar title.
      title: Text(title),
      actions: [
        Padding(
            padding: const EdgeInsets.only(right: 30),
            child: Align(
                alignment: Alignment.centerRight,
                child: _version(context, version)))
      ],
    );
  }
  */

  AppBar appBar(BuildContext context) {
    return AppBar(
      // Here we take the value from the MyHomePage object that was created by
      // the App.build method, and use it to set our appbar title.
      title: Text(title),
      actions: [
        Padding(
            padding: const EdgeInsets.only(right: 30),
            child: Align(
                alignment: Alignment.centerRight,
                child: _version(context, version)))
      ],
    );
  }

  Widget _version(BuildContext context, String version) {
    TextStyle? versionTextStyle = Constants.getVersionTextStyle(context);
    return Text('version: $version', style: versionTextStyle);
  }
}
