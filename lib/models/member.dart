class Member {
  String _name;

  String get name {
    print('get');
    return _name;
  }

  Member(this._name);

  set name(String name) {
    print('set');
    _name = name;
  }
}
