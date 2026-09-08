import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jiongtu/app_update_service.dart';

const _tag = 'android-123-1';
const _base = 'https://github.com/fenghengzhi/jiongtu/releases/download/$_tag';
final _bytes = utf8.encode('downloaded APK fixture');
final _hash = sha256.convert(_bytes).toString();

InstalledAppInfo _current({
  int code = 2001,
  List<String> abis = const ['arm64-v8a'],
  int sdk = 31,
}) => InstalledAppInfo(
  versionName: '1.0.0',
  versionCode: code,
  abis: abis,
  sdkInt: sdk,
);

Map<String, dynamic> _asset(String name, {int? size}) => {
  'name': name,
  'size': size ?? _bytes.length,
  'browser_download_url': '$_base/$name',
};

Map<String, dynamic> _package(String abi, int code) => {
  'name': 'jiongtu-$abi.apk',
  'abi': abi,
  'versionName': '1.0.0',
  'versionCode': code,
  'minSdk': 24,
  'size': _bytes.length,
  'sha256': _hash,
};

Map<String, dynamic> _release() => {
  'tag_name': _tag,
  'draft': false,
  'prerelease': false,
  'body': '修复图片浏览问题',
  'assets': [
    _asset('update.json'),
    for (final abi in ['armeabi-v7a', 'arm64-v8a', 'x86_64'])
      _asset('jiongtu-$abi.apk'),
  ],
};

Map<String, dynamic> _manifest() => {
  'schemaVersion': 1,
  'packageName': 'com.example.jiongtu',
  'tag': _tag,
  'assets': [
    _package('armeabi-v7a', 1002),
    _package('arm64-v8a', 2002),
    _package('x86_64', 4002),
  ],
};

AppUpdateService _service({
  Map<String, dynamic>? release,
  Map<String, dynamic>? manifest,
  int status = 200,
}) => AppUpdateService(
  clientFactory: () => MockClient((request) async {
    if (request.url.host == 'api.github.com') {
      expect(request.url.path, '/repos/fenghengzhi/jiongtu/releases/latest');
      return http.Response.bytes(
        utf8.encode(jsonEncode(release ?? _release())),
        status,
      );
    }
    expect(request.url.toString(), '$_base/update.json');
    return http.Response(jsonEncode(manifest ?? _manifest()), 200);
  }),
);

Matcher _failsWith(String text) => throwsA(
  isA<UpdateException>().having(
    (error) => error.message,
    'message',
    contains(text),
  ),
);

class _TestInstaller extends AndroidUpdateInstaller {
  _TestInstaller(this.directory);
  final Directory directory;
  @override
  Future<Directory> getDownloadDirectory() async => directory;
}

AppRelease _downloadRelease({String? hash, int? size}) => AppRelease(
  versionName: '1.0.0',
  versionCode: 2002,
  notes: '',
  downloadUrl: Uri.parse('$_base/jiongtu-arm64-v8a.apk'),
  size: size ?? _bytes.length,
  checksum: hash ?? _hash,
);

void main() {
  group('GitHub release checks', () {
    test('selects the installed ABI and actual version code', () async {
      final release = await _service().checkForUpdate(_current());
      expect(release!.versionCode, 2002);
      expect(release.downloadUrl.path, endsWith('jiongtu-arm64-v8a.apk'));
      expect(release.notes, '修复图片浏览问题');
      expect(release.checksum, _hash);
    });

    test('keeps 32-bit installs and supports x86_64', () async {
      final arm = await _service().checkForUpdate(
        _current(code: 1001, abis: ['armeabi-v7a', 'armeabi']),
      );
      final x64 = await _service().checkForUpdate(
        _current(code: 4001, abis: ['x86_64']),
      );
      expect(arm!.versionCode, 1002);
      expect(x64!.versionCode, 4002);
    });

    test('does not update equal or newer installed versions', () async {
      expect(await _service().checkForUpdate(_current(code: 2002)), isNull);
      expect(await _service().checkForUpdate(_current(code: 2010)), isNull);
    });

    test('rejects unsupported ABI and Android versions', () async {
      await expectLater(
        _service().checkForUpdate(_current(abis: ['x86'])),
        _failsWith('适合当前设备'),
      );
      await expectLater(
        _service().checkForUpdate(_current(sdk: 23)),
        _failsWith('更高版本的 Android'),
      );
    });

    test(
      'distinguishes missing releases, rate limits and server failures',
      () async {
        for (final status in [403, 429]) {
          await expectLater(
            _service(status: status).checkForUpdate(_current()),
            _failsWith('限制'),
          );
        }
        await expectLater(
          _service(status: 404).checkForUpdate(_current()),
          _failsWith('暂无已发布'),
        );
        await expectLater(
          _service(status: 500).checkForUpdate(_current()),
          _failsWith('HTTP 500'),
        );
      },
    );

    test('never installs drafts or prereleases', () async {
      for (final flag in ['draft', 'prerelease']) {
        final release = _release()..[flag] = true;
        await expectLater(
          _service(release: release).checkForUpdate(_current()),
          _failsWith('正式版本'),
        );
      }
    });

    test('handles legacy releases without metadata explicitly', () async {
      final release = _release()..['assets'] = <dynamic>[];
      await expectLater(
        _service(release: release).checkForUpdate(_current()),
        _failsWith('尚未提供'),
      );
    });

    test('rejects mismatched tags, packages and schema versions', () async {
      for (final entry in {
        'tag': 'old-tag',
        'packageName': 'other.app',
        'schemaVersion': 2,
      }.entries) {
        final manifest = _manifest()..[entry.key] = entry.value;
        await expectLater(
          _service(manifest: manifest).checkForUpdate(_current()),
          _failsWith('不匹配'),
        );
      }
    });

    test('rejects missing APK, incorrect size and unsafe URLs', () async {
      final missing = _release();
      (missing['assets'] as List).removeAt(2);
      await expectLater(
        _service(release: missing).checkForUpdate(_current()),
        _failsWith('不完整'),
      );
      final wrongSize = _release();
      wrongSize['assets'][2]['size'] = 1;
      await expectLater(
        _service(release: wrongSize).checkForUpdate(_current()),
        _failsWith('不完整'),
      );
      for (final index in [0, 2]) {
        final unsafe = _release();
        unsafe['assets'][index]['browser_download_url'] =
            'https://example.com/update.apk';
        await expectLater(
          _service(release: unsafe).checkForUpdate(_current()),
          _failsWith('不属于本项目'),
        );
      }
    });

    test(
      'rejects malformed metadata and network errors with readable messages',
      () async {
        final malformed = _manifest();
        malformed['assets'][1]['versionCode'] = '2002';
        await expectLater(
          _service(manifest: malformed).checkForUpdate(_current()),
          _failsWith('格式有误'),
        );
        final invalidHash = _manifest();
        invalidHash['assets'][1]['sha256'] = 'invalid';
        await expectLater(
          _service(manifest: invalidHash).checkForUpdate(_current()),
          _failsWith('不完整'),
        );
        for (final error in [
          http.ClientException('offline'),
          TimeoutException('timeout'),
        ]) {
          final service = AppUpdateService(
            clientFactory: () => MockClient((_) async => throw error),
          );
          await expectLater(
            service.checkForUpdate(_current()),
            _failsWith('网络'),
          );
        }
      },
    );
  });

  group('APK downloads', () {
    late Directory directory;
    setUp(
      () async => directory = await Directory.systemTemp.createTemp(
        'jiongtu-update-test-',
      ),
    );
    tearDown(() async => directory.delete(recursive: true));

    AppUpdateService downloader(List<int> bytes) => AppUpdateService(
      installer: _TestInstaller(directory),
      clientFactory: () =>
          MockClient((_) async => http.Response.bytes(bytes, 200)),
    );

    test(
      'streams bytes, reports progress and only returns a verified APK',
      () async {
        final progress = <int>[];
        final file = await downloader(_bytes)
            .download(_downloadRelease(), (received, total) {
              expect(total, _bytes.length);
              progress.add(received);
            });
        expect(await file.readAsBytes(), _bytes);
        expect(file.path, endsWith('.apk'));
        expect(progress.first, 0);
        expect(progress.last, _bytes.length);
        expect(
          await directory
              .list(recursive: true)
              .where((file) => file.path.endsWith('.part'))
              .isEmpty,
          isTrue,
        );
      },
    );

    test('removes downloads with bad checksums or wrong lengths', () async {
      await expectLater(
        downloader(_bytes)
            .download(_downloadRelease(hash: '0' * 64), (_, _) {}),
        _failsWith('校验失败'),
      );
      expect(await directory.list().isEmpty, isTrue);
      await expectLater(
        downloader([1]).download(_downloadRelease(), (_, _) {}),
        _failsWith('大小不匹配'),
      );
      expect(await directory.list().isEmpty, isTrue);
    });

    test(
      'detects truncated and oversized streams without content length',
      () async {
        for (final bytes in [
          [1],
          [..._bytes, 0],
        ]) {
          final service = AppUpdateService(
            installer: _TestInstaller(directory),
            clientFactory: () => MockClient.streaming(
              (_, _) async => http.StreamedResponse(Stream.value(bytes), 200),
            ),
          );
          await expectLater(
            service.download(_downloadRelease(), (_, _) {}),
            throwsA(isA<UpdateException>()),
          );
          expect(await directory.list().isEmpty, isTrue);
        }
      },
    );

    test('cancels without returning an APK and allows a clean retry', () async {
      final service = downloader(_bytes);
      await expectLater(
        service.download(_downloadRelease(), (received, _) {
          if (received > 0) service.cancelDownload();
        }),
        _failsWith('取消'),
      );
      expect(await directory.list().isEmpty, isTrue);
      final file = await service.download(_downloadRelease(), (_, _) {});
      expect(await file.exists(), isTrue);
    });
  });
}
