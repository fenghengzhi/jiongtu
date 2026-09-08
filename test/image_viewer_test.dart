import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiongtu/CustomCacheManager.dart';
import 'package:jiongtu/ImageViewer.dart';
import 'package:jiongtu/PicInfo.dart';

const _imageUrl = 'https://example.test/gesture-fixture.png';
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryImageCache cache;
  late List<MethodCall> shareCalls;
  final imageFinder = find.byType(CachedNetworkImage);

  setUp(() {
    cache = _MemoryImageCache();
    CustomCacheManager.instance = cache;
    shareCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, (call) async {
          shareCalls.add(call);
          return 'test-share';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null);
  });

  Future<void> showViewer(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewer(PicInfo(pic_url: _imageUrl, width: 160, height: 120)),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        CachedNetworkImageProvider(_imageUrl, cacheManager: cache),
        tester.element(imageFinder),
      );
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final bothOutside in [true, false]) {
    testWidgets(
      bothOutside
          ? 'Pinch zooms in and out with both fingers on the black background'
          : 'Pinch zooms in and out with one finger outside the image',
      (tester) async {
        await showViewer(tester);
        final initialRect = tester.getRect(imageFinder);
        final firstPoint =
            initialRect.center + Offset(bothOutside ? -140 : -20, 0);
        final secondPoint =
            initialRect.center + Offset(bothOutside ? 140 : 220, 0);
        expect(initialRect.contains(firstPoint), !bothOutside);
        expect(initialRect.contains(secondPoint), isFalse);

        final pinch = await _Pinch.start(tester, firstPoint, secondPoint);
        await pinch.move(tester, 1.2);
        final warmRect = tester.getRect(imageFinder);
        final box = tester.renderObject<RenderBox>(imageFinder);
        final anchor = box.globalToLocal(pinch.focalPoint);

        await pinch.move(tester, 1.8);
        final zoomedRect = tester.getRect(imageFinder);
        expect(zoomedRect.width, greaterThan(initialRect.width));
        expect(zoomedRect.width, greaterThan(warmRect.width));
        expect(
          (box.localToGlobal(anchor) - pinch.focalPoint).distance,
          lessThan(0.01),
        );

        await pinch.move(tester, 0.8);
        expect(tester.getRect(imageFinder).width, lessThan(zoomedRect.width));
        await pinch.end(tester);

        // Start a second gesture outside an already transformed image.
        final previousRect = tester.getRect(imageFinder);
        final viewport = tester.getRect(find.byType(OverflowBox));
        final nextFocus = viewport.topLeft + const Offset(150, 130);
        final nextFirst = nextFocus - const Offset(40, 0);
        final nextSecond = nextFocus + const Offset(40, 0);
        expect(previousRect.contains(nextFirst), isFalse);
        expect(previousRect.contains(nextSecond), isFalse);
        final nextPinch = await _Pinch.start(tester, nextFirst, nextSecond);
        expect(tester.getRect(imageFinder), previousRect);
        await nextPinch.move(tester, 1.5);
        final nextAnchor = box.globalToLocal(nextFocus);
        final nextWarmRect = tester.getRect(imageFinder);
        const pan = Offset(24, 16);
        await nextPinch.move(tester, 2, translation: pan);
        expect(
          tester.getRect(imageFinder).width,
          greaterThan(nextWarmRect.width),
        );
        expect(
          (box.localToGlobal(nextAnchor) - (nextFocus + pan)).distance,
          lessThan(0.01),
        );
        await nextPinch.end(tester);
        expect(shareCalls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Long press shares the image but not the black background', (
    tester,
  ) async {
    await showViewer(tester);
    final imageRect = tester.getRect(imageFinder);
    final backgroundPoint = imageRect.center + const Offset(180, 0);
    expect(imageRect.contains(backgroundPoint), isFalse);
    await tester.longPressAt(backgroundPoint);
    await tester.pumpAndSettle();
    expect(shareCalls, isEmpty);

    await tester.longPress(imageFinder);
    await tester.pumpAndSettle();
    expect(shareCalls, hasLength(1));
    expect(shareCalls.single.method, 'share');
    expect(shareCalls.single.arguments['paths'], [cache.file.path]);
    expect(tester.takeException(), isNull);
  });
}

class _Pinch {
  _Pinch(this.first, this.second, this.firstPoint, this.secondPoint);

  final TestGesture first;
  final TestGesture second;
  final Offset firstPoint;
  final Offset secondPoint;

  Offset get focalPoint => (firstPoint + secondPoint) / 2;

  static Future<_Pinch> start(
    WidgetTester tester,
    Offset firstPoint,
    Offset secondPoint,
  ) async {
    final first = await tester.startGesture(firstPoint, pointer: 1);
    final second = await tester.startGesture(secondPoint, pointer: 2);
    await tester.pump();
    return _Pinch(first, second, firstPoint, secondPoint);
  }

  Future<void> move(
    WidgetTester tester,
    double factor, {
    Offset translation = Offset.zero,
  }) async {
    await first.moveTo(
      focalPoint + (firstPoint - focalPoint) * factor + translation,
    );
    await second.moveTo(
      focalPoint + (secondPoint - focalPoint) * factor + translation,
    );
    await tester.pump();
  }

  Future<void> end(WidgetTester tester) async {
    await first.up();
    await second.up();
    await tester.pump();
  }
}

class _MemoryImageCache implements CacheManager {
  final File file = MemoryFileSystem().file('/gesture-fixture.png')
    ..writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => Stream.value(FileInfo(file, FileSource.Cache, DateTime(2100), url));

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async => file;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Unexpected cache call: ${invocation.memberName}',
  );
}
