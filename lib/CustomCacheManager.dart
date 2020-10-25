import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CustomCacheManager extends BaseCacheManager {
  static const key = "customCache";

  static CustomCacheManager _instance;

  factory CustomCacheManager() {
    if (_instance == null) {
      _instance = CustomCacheManager._();
    }
    return _instance;
  }

  CustomCacheManager._()
      : super(key,
      maxAgeCacheObject: Duration(days: 30), maxNrOfCacheObjects: 20000);

  getFilePath() async {
    var directory = await getTemporaryDirectory();
    return p.join(directory.path, key);
  }

  getSize() async {
    try {
      final path = await getFilePath();
      // print(path);
      final directory = Directory(path);
      final listStream = directory.list();
      final list = <FileSystemEntity>[];
      await for (FileSystemEntity fileSystemEntity in listStream) {
        list.add(fileSystemEntity);
      }
      final stats = await Future.wait(
          list.map((fileSystemEntity) => fileSystemEntity.stat()));
      final fileStats =
      stats.where((stat) => stat.type == FileSystemEntityType.file);
      final sizes = fileStats.map((stat) => stat.size);
      final size = sizes.isEmpty ? 0 : sizes.reduce((v, e) => v + e);
      // print(size);
      return size;
    } catch (e){
      return 0;
    }
  }
}
