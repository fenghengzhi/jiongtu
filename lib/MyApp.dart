import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'MyHomePage.dart';
import 'MyStore.dart';

class MyApp extends StatefulWidget {
  static final store = MyStore();

  // This widget is the root of your application.
  @override
  _MyApp createState() => _MyApp();
}

class _MyApp extends State<MyApp> {
  @override
  Widget build(BuildContext context) => Observer(
      builder: (_) => MaterialApp(
          title: '多玩图库',
          theme:
              MyApp.store.darkTheme ? ThemeData.dark() : ThemeData.light(),
          home: MyHomePage()));
}
