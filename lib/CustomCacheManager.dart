import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart'
    as c;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class IOFileSystem implements c.FileSystem {
  final Future<Directory> _fileDir;

  IOFileSystem(String key) : _fileDir = createDirectory(key);

  static Future<Directory> createDirectory(String key) async {
    final baseDir = await getTemporaryDirectory();
    final path = p.join(baseDir.path, key);
    final fs = const LocalFileSystem();
    final directory = fs.directory((path));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<File> createFile(String name) async {
    assert(name != null);
    return (await _fileDir).childFile(name);
  }
}

class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 20,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileSystem: IOFileSystem(key),
      fileService: HttpFileService(),
    ),
  );

  getSize() async {
    try {
      final directory =
          await IOFileSystem.createDirectory(CustomCacheManager.key);

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
    } catch (e) {
      return 0;
    }
  }
}
