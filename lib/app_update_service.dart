import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class InstalledAppInfo {
  const InstalledAppInfo({
    required this.versionName,
    required this.versionCode,
    required this.abis,
    required this.sdkInt,
  });

  final String versionName;
  final int versionCode;
  final List<String> abis;
  final int sdkInt;
  String get label => '$versionName ($versionCode)';
}

class AppRelease {
  const AppRelease({
    required this.versionName,
    required this.versionCode,
    required this.notes,
    required this.downloadUrl,
    required this.size,
    required this.checksum,
  });

  final String versionName;
  final int versionCode;
  final String notes;
  final Uri downloadUrl;
  final int size;
  final String checksum;
  String get label => '$versionName ($versionCode)';
}

class AndroidUpdateInstaller {
  static const channel = MethodChannel('com.example.jiongtu/updates');

  Future<InstalledAppInfo> getInstalledApp() async {
    final info = (await channel.invokeMapMethod<String, dynamic>(
      'getAppInfo',
    ))!;
    return InstalledAppInfo(
      versionName: info['versionName'] as String,
      versionCode: info['versionCode'] as int,
      abis: List<String>.from(info['abis'] as List),
      sdkInt: info['sdkInt'] as int,
    );
  }

  Future<Directory> getDownloadDirectory() async =>
      Directory((await channel.invokeMethod<String>('getDownloadDirectory'))!);

  Future<bool> canInstall() async =>
      await channel.invokeMethod<bool>('canInstallPackages') ?? false;

  Future<bool> requestPermission() async =>
      await channel.invokeMethod<bool>('requestInstallPermission') ?? false;

  Future<void> install(File apk, AppRelease release) =>
      channel.invokeMethod<void>('installApk', {
        'path': apk.path,
        'versionCode': release.versionCode,
        'versionName': release.versionName,
      });
}

class AppUpdateService {
  AppUpdateService({
    AndroidUpdateInstaller? installer,
    http.Client Function()? clientFactory,
  }) : installer = installer ?? AndroidUpdateInstaller(),
       _clientFactory = clientFactory ?? http.Client.new;

  static const repository = 'fenghengzhi/jiongtu';
  static const packageName = 'com.example.jiongtu';
  static const _timeout = Duration(seconds: 30);
  final AndroidUpdateInstaller installer;
  final http.Client Function() _clientFactory;
  http.Client? _downloadClient;
  bool _cancelled = false;

  Future<AppRelease?> checkForUpdate(InstalledAppInfo current) async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(
            Uri.https('api.github.com', '/repos/$repository/releases/latest'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'jiongtu-updater',
            },
          )
          .timeout(_timeout);
      if (response.statusCode == 404) {
        throw const UpdateException('暂无已发布的版本，请稍后再试。');
      }
      _requireSuccess(response.statusCode);
      final release =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (release['draft'] != false || release['prerelease'] != false) {
        throw const UpdateException('暂时没有可用的正式版本。');
      }
      final tag = release['tag_name'] as String;
      final assets = (release['assets'] as List).cast<Map<String, dynamic>>();
      final manifests = assets.where((asset) => asset['name'] == 'update.json');
      if (manifests.length != 1) {
        throw const UpdateException('此版本尚未提供应用内更新信息，请等待后续发布。');
      }
      final manifestResponse = await client
          .get(_assetUrl(manifests.single, tag))
          .timeout(_timeout);
      _requireSuccess(manifestResponse.statusCode);
      final manifest = jsonDecode(
        utf8.decode(manifestResponse.bodyBytes),
      ) as Map<String, dynamic>;
      if (manifest['schemaVersion'] != 1 ||
          manifest['packageName'] != packageName ||
          manifest['tag'] != tag) {
        throw const UpdateException('更新信息不匹配，无法安装此版本。');
      }
      final packages = (manifest['assets'] as List)
          .cast<Map<String, dynamic>>();
      Map<String, dynamic>? selected;
      // Native code reports ABIs for the running process, preserving 32-bit
      // installs on 64-bit devices and Flutter's per-ABI versionCode offsets.
      for (final abi in current.abis) {
        for (final candidate in packages) {
          if (candidate['abi'] == abi) {
            selected = candidate;
            break;
          }
        }
        if (selected != null) break;
      }
      if (selected == null) {
        throw const UpdateException('此版本没有适合当前设备的安装包。');
      }
      final versionCode = selected['versionCode'] as int;
      final versionName = selected['versionName'] as String;
      final minSdk = selected['minSdk'] as int;
      final size = selected['size'] as int;
      final checksum = selected['sha256'] as String;
      if (versionCode <= 0 ||
          versionName.isEmpty ||
          minSdk <= 0 ||
          size <= 0 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum)) {
        throw const UpdateException('更新信息不完整，请稍后再试。');
      }
      if (versionCode <= current.versionCode) return null;
      if (minSdk > current.sdkInt) {
        throw const UpdateException('新版本需要更高版本的 Android，当前设备无法安装。');
      }
      final matching = assets.where(
        (asset) => asset['name'] == selected!['name'],
      );
      if (matching.length != 1 || matching.single['size'] != size) {
        throw const UpdateException('发布的安装包不完整，请稍后再试。');
      }
      return AppRelease(
        versionName: versionName,
        versionCode: versionCode,
        notes: (release['body'] as String?) ?? '',
        downloadUrl: _assetUrl(matching.single, tag),
        size: size,
        checksum: checksum,
      );
    } on UpdateException {
      rethrow;
    } on TimeoutException {
      throw const UpdateException('连接 GitHub 超时，请检查网络后重试。');
    } on http.ClientException {
      throw const UpdateException('无法连接 GitHub，请检查网络后重试。');
    } on IOException {
      throw const UpdateException('无法连接 GitHub，请检查网络后重试。');
    } on FormatException {
      throw const UpdateException('无法读取更新信息，请稍后再试。');
    } on TypeError {
      throw const UpdateException('更新信息格式有误，请稍后再试。');
    } finally {
      client.close();
    }
  }

  Uri _assetUrl(Map<String, dynamic> asset, String tag) {
    final uri = Uri.parse(asset['browser_download_url'] as String);
    final expected = Uri.https(
      'github.com',
      '/$repository/releases/download/$tag/${asset['name']}',
    );
    if (uri != expected) {
      throw const UpdateException('安装包下载地址不属于本项目，已停止更新。');
    }
    return uri;
  }

  void _requireSuccess(int status) {
    if (status == 403 || status == 429) {
      throw const UpdateException('GitHub 暂时限制了请求，请稍后再试。');
    }
    if (status != 200) {
      throw UpdateException('获取更新失败（HTTP $status），请稍后再试。');
    }
  }

  Future<File> download(
    AppRelease release,
    void Function(int received, int total) onProgress,
  ) async {
    if (_downloadClient != null) {
      throw const UpdateException('已有更新正在下载。');
    }
    final client = _clientFactory();
    _downloadClient = client;
    _cancelled = false;
    File? partial;
    RandomAccessFile? output;
    try {
      final directory = await installer.getDownloadDirectory();
      await directory.create(recursive: true);
      // Each attempt owns its files; closing a dialog can never delete a later
      // attempt's download, even when cancellation races with an HTTP response.
      final attempt = await directory.createTemp('download-');
      partial = File('${attempt.path}/update.apk.part');
      output = await partial.open(mode: FileMode.write);
      _checkCancelled();
      final response = await client
          .send(http.Request('GET', release.downloadUrl))
          .timeout(_timeout);
      _requireSuccess(response.statusCode);
      if (response.contentLength != null &&
          response.contentLength != release.size) {
        throw const UpdateException('安装包大小不匹配，请重新检查更新。');
      }
      var received = 0;
      onProgress(0, release.size);
      await for (final chunk in response.stream.timeout(_timeout)) {
        _checkCancelled();
        received += chunk.length;
        if (received > release.size) {
          throw const UpdateException('安装包大小不匹配，请重新检查更新。');
        }
        await output.writeFrom(chunk);
        onProgress(received, release.size);
      }
      await output.close();
      output = null;
      _checkCancelled();
      if (received != release.size ||
          (await sha256.bind(partial.openRead()).first).toString() !=
              release.checksum) {
        throw const UpdateException('安装包校验失败，请重新下载。');
      }
      _checkCancelled();
      return await partial.rename('${attempt.path}/update.apk');
    } on UpdateException {
      rethrow;
    } on TimeoutException {
      throw const UpdateException('下载超时，请检查网络后重试。');
    } on http.ClientException {
      throw UpdateException(_cancelled ? '已取消下载。' : '下载失败，请检查网络后重试。');
    } on IOException {
      throw const UpdateException('下载失败，请检查网络和设备剩余空间后重试。');
    } finally {
      client.close();
      _downloadClient = null;
      await output?.close();
      if (partial != null && await partial.exists()) {
        await partial.parent.delete(recursive: true);
      }
    }
  }

  void _checkCancelled() {
    if (_cancelled) throw const UpdateException('已取消下载。');
  }

  void cancelDownload() {
    _cancelled = true;
    _downloadClient?.close();
  }
}
