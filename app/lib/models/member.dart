import 'package:flutter/cupertino.dart';

class Member {
  String _name;

  Member(this._name);

  String get name {
    debugPrint('get');
    return _name;
  }

  set name(String name) {
    debugPrint('set');
    _name = name;
  }
}
