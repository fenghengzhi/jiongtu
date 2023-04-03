import 'package:flutter/material.dart';
import 'package:rxdart/subjects.dart';

import 'Settings.dart';
import 'Youminxingkong.dart';
import 'Youxia.dart';

class MyHomePage extends StatefulWidget {
  // MyHomePage({Key key}) : super(key: key);
  static final bottomNavigationEvent = PublishSubject<int>();

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final _controller = PageController(
    initialPage: 0,
  );

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  int _selectedIndex = 0;

  final _widgetOptions = [Youxia(), Youminxingkong(), Settings()];

  @override
  Widget build(BuildContext context) => Scaffold(
      // body: Center(
      //   // child: _widgetOptions.elementAt(_selectedIndex),
      //   child: _widgetOptions[_selectedIndex],
      // ),
      body: PageView(
        controller: _controller,
        children: _widgetOptions,
        physics: const NeverScrollableScrollPhysics(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: const Icon(Icons.fiber_new), label: '游侠囧图'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.fiber_new), label: '游民星空'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.settings), label: '设置'),
        ],
        currentIndex: _selectedIndex,
        fixedColor: Colors.deepPurple,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ));

  void _onItemTapped(int index) {
    _controller.jumpToPage(index);
    setState(() {
      _selectedIndex = index;
      MyHomePage.bottomNavigationEvent.add(index);
    });
  }
}
