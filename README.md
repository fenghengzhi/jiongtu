# jiongtu

游侠囧图与游民星空图片浏览器，支持图片缓存、视频播放、分享和暗黑模式。

## 开发环境

- Flutter **3.47.2 stable**（Dart **3.13.2**）；版本也记录在 `.fvmrc` 中。
- Android 构建使用 JDK **17**、Android SDK **36**、NDK **28.2.13676358**。
- Gradle **9.3.1**、Android Gradle Plugin **9.1.0**、Kotlin **2.4.0**。
- 最低支持 Android **7.0 / API 24**，与当前 Flutter 默认最低版本一致。

已安装 Flutter 的环境可使用 `flutter channel stable` 和 `flutter upgrade` 更新 SDK。
使用 FVM 时，运行 `fvm install`，并为下列 `flutter` / `dart` 命令添加 `fvm` 前缀。

## 安装与运行

```sh
flutter pub get
dart run build_runner build
flutter run
```

`android/local.properties` 由 Flutter 为本机生成，不提交到版本控制。
如果 Flutter 找不到 JDK，可运行 `flutter config --jdk-dir=/path/to/jdk`。

## 验证

```sh
flutter analyze --no-fatal-infos
flutter test
```

静态检查保留项目已有的命名和代码风格提示；错误和警告仍会导致检查失败。
页面测试使用模拟接口数据，不依赖外部站点，覆盖底部导航、暗黑模式保存和缓存确认弹窗。

## Android 打包

```sh
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

产物位于 `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`。
当前沿用开发签名，正式发布前需配置发布密钥。

## 本次升级

- 从 Dart 2 迁移到 Dart 3，更新依赖约束和锁文件。
- 移除未使用且不支持空安全的 `gbk2utf8`；显式声明缓存实现使用的依赖。
- Android 改用声明式 Flutter Gradle 插件和 AGP 9 内置 Kotlin；保留 Flutter 3.47 仍需要的旧 AGP DSL 兼容开关。
- 更新图片分享、视频控制器和图片变换 API，重新生成 MobX 代码。

版本来源：[Flutter SDK archive](https://docs.flutter.dev/install/archive)。
