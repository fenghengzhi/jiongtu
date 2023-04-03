import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'CustomCacheManager.dart';
import 'MyApp.dart';
import 'MyHomePage.dart';

class _Settings extends State<Settings> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _subscriptions = <StreamSubscription>[];
  int _size = 0;

  @override
  Widget build(BuildContext context) => Scrollbar(
          child: ListView(
        children: <Widget>[
          ListTile(
            title: const Text('清除缓存'),
            subtitle: Text('${(_size / 1024 / 1024).toStringAsFixed(2)}mb'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showDialog,
          ),
          const Divider(),
          ListTile(
            title: const Text('暗黑模式'),
            trailing: Observer(
                builder: (_) => Switch(
                    value: MyApp.store.darkTheme,
                    onChanged: MyApp.store.setTheme)),
          ),
          const Divider()
        ],
      ));

  @override
  void initState() {
    super.initState();
    _getCacheSize();
    _subscriptions.add(MyHomePage.bottomNavigationEvent.stream
        .where((index) => index == 2)
        .listen((_) => _getCacheSize()));
  }

  @override
  void dispose() {
    super.dispose();
    _subscriptions.forEach((_subscription) => _subscription.cancel());
  }

  _getCacheSize() async {
    final size = await CustomCacheManager().getSize();
    setState(() {
      _size = size;
    });
  }

  _clearCache() async {
    await CustomCacheManager.instance.emptyCache();
    // await CustomCacheManager().emptyCache();
    await _getCacheSize();
  }

  _showDialog() {
    showDialog(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
              title: const Text("确认清除缓存吗？"),
//          content: new Text("Alert Dialog body"),
              actions: <Widget>[
                // usually buttons at the bottom of the dialog
                TextButton(
                  child: const Text("取消"),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                    child: const Text("确认"),
                    onPressed: () async {
                      await _clearCache();
                      Navigator.of(dialogContext).pop();
                    }),
              ],
            ));
  }
}

class Settings extends StatefulWidget {
  @override
  _Settings createState() => _Settings();
}
