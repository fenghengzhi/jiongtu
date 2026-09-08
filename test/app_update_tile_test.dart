import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiongtu/app_update_service.dart';
import 'package:jiongtu/app_update_tile.dart';

final _release = AppRelease(
  versionName: '1.0.1',
  versionCode: 2002,
  notes: '更新说明',
  downloadUrl: Uri.parse('https://github.com/fenghengzhi/jiongtu'),
  size: 100,
  checksum: '',
);

class _Installer extends AndroidUpdateInstaller {
  bool permitted = true;
  bool grantPermission = true;
  int installs = 0;
  int permissionRequests = 0;

  @override
  Future<InstalledAppInfo> getInstalledApp() async => const InstalledAppInfo(
    versionName: '1.0.0',
    versionCode: 2001,
    abis: ['arm64-v8a'],
    sdkInt: 31,
  );
  @override
  Future<bool> canInstall() async => permitted;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permitted = grantPermission;
  }

  @override
  Future<void> install(File apk, AppRelease release) async {
    installs++;
  }
}

class _Service extends AppUpdateService {
  _Service(_Installer installer) : super(installer: installer);
  bool available = true;
  bool failDownload = false;
  int downloads = 0;
  int checks = 0;
  bool cancelled = false;
  Completer<void>? holdCheck;
  Completer<File>? holdDownload;

  @override
  Future<AppRelease?> checkForUpdate(InstalledAppInfo current) async {
    checks++;
    await holdCheck?.future;
    return available ? _release : null;
  }

  @override
  Future<File> download(
    AppRelease release,
    void Function(int, int) onProgress,
  ) async {
    downloads++;
    onProgress(50, 100);
    if (failDownload) throw const UpdateException('下载失败，请重试。');
    return holdDownload?.future ?? File('/unused/update.apk');
  }

  @override
  void cancelDownload() => cancelled = true;
}

void main() {
  late _Installer installer;
  late _Service service;
  setUp(() {
    installer = _Installer();
    service = _Service(installer);
  });

  Future<void> showTile(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppUpdateTile(service: service)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openUpdate(WidgetTester tester) async {
    await showTile(tester);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows installed version without checking automatically', (
    tester,
  ) async {
    await showTile(tester);
    expect(find.textContaining('当前版本 1.0.0 (2001)'), findsOneWidget);
    expect(service.checks, 0);
    service.available = false;
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已是最新版本'), findsOneWidget);
  });

  testWidgets('ignores duplicate checks while a request is pending', (
    tester,
  ) async {
    service.holdCheck = Completer<void>();
    await showTile(tester);
    await tester.tap(find.text('检查更新'));
    await tester.pump();
    await tester.tap(find.text('检查更新'));
    expect(service.checks, 1);
    service.holdCheck!.complete();
    await tester.pumpAndSettle();
    expect(find.text('发现新版本'), findsOneWidget);
  });

  testWidgets('downloads only after confirmation, then launches installer', (
    tester,
  ) async {
    await openUpdate(tester);
    expect(find.text('更新说明'), findsOneWidget);
    expect(service.downloads, 0);
    await tester.tap(find.text('下载并安装'));
    await tester.pumpAndSettle();
    expect(service.downloads, 1);
    expect(installer.installs, 1);
    expect(find.textContaining('已打开系统安装器'), findsOneWidget);
    await tester.tap(find.text('再次安装'));
    await tester.pumpAndSettle();
    expect(service.downloads, 1);
    expect(installer.installs, 2);
  });

  testWidgets(
    'retries denied permission and resumes without downloading again',
    (tester) async {
      installer.permitted = false;
      installer.grantPermission = false;
      await openUpdate(tester);
      await tester.tap(find.text('下载并安装'));
      await tester.pumpAndSettle();
      expect(find.text('允许安装'), findsOneWidget);
      expect(installer.installs, 0);
      await tester.tap(find.text('允许安装'));
      await tester.pumpAndSettle();
      expect(find.textContaining('尚未允许安装'), findsOneWidget);
      expect(installer.installs, 0);
      installer.grantPermission = true;
      await tester.tap(find.text('允许安装'));
      await tester.pumpAndSettle();
      expect(installer.permissionRequests, 2);
      expect(installer.installs, 1);
      expect(service.downloads, 1);
    },
  );

  testWidgets('failed downloads can be retried', (tester) async {
    service.failDownload = true;
    await openUpdate(tester);
    await tester.tap(find.text('下载并安装'));
    await tester.pumpAndSettle();
    expect(find.text('下载失败，请重试。'), findsOneWidget);
    expect(installer.installs, 0);
    service.failDownload = false;
    await tester.tap(find.text('下载并安装'));
    await tester.pumpAndSettle();
    expect(installer.installs, 1);
  });

  testWidgets('closing a download cancels it and prevents late installation', (
    tester,
  ) async {
    service.holdDownload = Completer<File>();
    await openUpdate(tester);
    await tester.tap(find.text('下载并安装'));
    await tester.pump();
    expect(find.text('正在下载 50%'), findsOneWidget);
    await tester.tap(find.text('取消下载'));
    await tester.pumpAndSettle();
    expect(service.cancelled, isTrue);
    service.holdDownload!.complete(File('/unused/update.apk'));
    await tester.pumpAndSettle();
    expect(installer.installs, 0);
    expect(tester.takeException(), isNull);
  });
}
