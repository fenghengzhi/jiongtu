import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jiongtu/MyApp.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Cache size falls back to zero when no platform directory is available.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => null,
        );
  });

  testWidgets('Home tabs render and settings persist the dark theme', (
    WidgetTester tester,
  ) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(MyApp());
        await tester.pumpAndSettle();

        expect(find.text('游侠囧图'), findsOneWidget);
        expect(find.text('游民星空'), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
        expect(
          tester
              .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
              .currentIndex,
          0,
        );

        await tester.tap(find.text('游民星空'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
              .currentIndex,
          1,
        );

        await tester.tap(find.text('设置'));
        await tester.pumpAndSettle();
        expect(find.text('清除缓存'), findsOneWidget);
        expect(find.text('暗黑模式'), findsOneWidget);

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MaterialApp>(find.byType(MaterialApp))
              .theme!
              .brightness,
          Brightness.dark,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('darkTheme'), isTrue);

        await tester.tap(find.text('清除缓存'));
        await tester.pumpAndSettle();
        expect(find.text('确认清除缓存吗？'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('确认清除缓存吗？'), findsNothing);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        if (request.url.host == 'api3.ali213.net') {
          return http.Response('{"data":{"article":[]}}', 200);
        }
        if (request.url.host == 'www.gamersky.com') {
          return http.Response('<html></html>', 200);
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );
  });
}
