import 'package:flutter/material.dart';

class Constants {
  //const Constants();

  static const String version = '0.0.22';

  static const String apiUrl =
      'https://script.googleapis.com/v1/scripts/AKfycbw_XU82LUQ7FMhf6JHL8QRnG8FHAgPktqfn3Th9uNmq5dxhBBk44bOMNuxWJDIngJvE:run';

  static const String tokenUrl = 'https://oauth2.googleapis.com/token';

  static const String clientId =
      '899530760082-skgo3k4sjv5la566sa598icfgdsusmgt.apps.googleusercontent.com';
  static const String clientSecret = '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';
  static const String refreshToken =
      '1//04ArNHM647K8xCgYIARAAGAQSNwF-L9IrOIVijhjy9mgU-tHC5LDCmV9BINUXbhUal-bDSNrAUFsCZScnq5dg92CkEYphLjaNVUw';
  //final String scope =
  //'https://www.googleapis.com/auth/spreadsheets';
  //'https://www.googleapis.com/auth/drive';

  static final List<String> nameList = <String>[
    //'test',
    '八木',
    '大滝',
    '山本',
    '広瀬',
    '坂下',
    '西本'
  ];

  //static const String
  static const double paddingMiddium = 10;
  static const String locale = 'ja';

  static const EdgeInsets topBottomPadding = EdgeInsets.fromLTRB(
      0, Constants.paddingMiddium, 0, Constants.paddingMiddium);
  static const EdgeInsets allPadding = EdgeInsets.all(Constants.paddingMiddium);
  static const Duration wait100Milliseconds = Duration(milliseconds: 100);

  static const Color green = Color.fromARGB(255, 210, 255, 212);
  static const Color red = Color.fromARGB(255, 255, 213, 227);
  static const Color gray = Color.fromARGB(255, 218, 218, 218);

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
