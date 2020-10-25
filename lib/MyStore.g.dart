// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'MyStore.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic

mixin _$MyStore on _MyStore, Store {
  final _$darkThemeAtom = Atom(name: '_MyStore.darkTheme');

  @override
  bool get darkTheme {
    _$darkThemeAtom.reportRead();
    return super.darkTheme;
  }

  @override
  set darkTheme(bool value) {
    _$darkThemeAtom.reportWrite(value, super.darkTheme, () {
      super.darkTheme = value;
    });
  }

  final _$_MyStoreActionController = ActionController(name: '_MyStore');

  @override
  dynamic _setTheme(bool _darkTheme) {
    final _$actionInfo =
        _$_MyStoreActionController.startAction(name: '_MyStore._setTheme');
    try {
      return super._setTheme(_darkTheme);
    } finally {
      _$_MyStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
darkTheme: ${darkTheme}
    ''';
  }
}
