// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'MyStore.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$MyStore on _MyStore, Store {
  late final _$darkThemeAtom =
      Atom(name: '_MyStore.darkTheme', context: context);

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

  late final _$_MyStoreActionController =
      ActionController(name: '_MyStore', context: context);

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
