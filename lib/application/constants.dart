import 'package:flutter/material.dart';

import '../models/user.dart';

class Constants {
  //const Constants();

  static const String version = '0.0.36';

  static const String apiUrl =
      'https://script.googleapis.com/v1/scripts/AKfycbzBB5YH8gKCghNfnIylIe5uaxkr8ekYbCcQtpbxnQv-LJyCBOIfm8e-BuIhYc1L64D6:run';

  static const String tokenUrl = 'https://oauth2.googleapis.com/token';

  static const String clientId =
      '899530760082-skgo3k4sjv5la566sa598icfgdsusmgt.apps.googleusercontent.com';
  static const String clientSecret = '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';
  static const String refreshToken =
      '1//049NpcRbl9qEiCgYIARAAGAQSNwF-L9IrPOneYPhX5iL4BqAbJjlunaJM5BLO4AoxnPmAGOJy10tqMzmgfnpK55MwNxVoQEIQd0M';
  //final String scope =
  //'https://www.googleapis.com/auth/spreadsheets';
  //'https://www.googleapis.com/auth/drive';

  static final List<User> userList = <User>[
    User(name: '八木', password: 'tyagi'),
    User(name: '大滝', password: 'kotaki'),
    User(name: '山本', password: 'kyamamoto'),
    User(name: '広瀬', password: 'yhirose'),
    User(name: '坂下', password: 'msakasita'),
    User(name: '西本', password: 'mnisimoto'),
  ];

  static const double paddingMiddium = 10;
  static const String locale = 'ja';

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
