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

## GitHub 自动发布

每次 push 到 `master` 都会触发 [Android Release](.github/workflows/android-release.yml)：

1. 从 `.fvmrc` 安装 Flutter，准备 Java 17 和 Android 构建工具。
2. 安装锁定依赖、生成 MobX 代码，运行静态检查和页面测试。
3. 构建 ARMv7、ARM64、x86_64 三种 release APK，以工作流运行序号作为构建号。
4. 将 APK 和 `SHA256SUMS` 上传到 [GitHub Releases](https://github.com/fenghengzhi/jiongtu/releases)，并在 Actions 中保留 14 天的构建附件。

标签格式为 `android-<run_id>-<run_attempt>`，指向实际构建的提交；重跑使用新标签，保留上一次的发布产物。也可在 Actions 页面选择 `master` 手动运行。
发布使用工作流自带的 `GITHUB_TOKEN`，无需额外配置个人访问令牌。

当前 CI 沿用开发签名，临时构建环境每次生成的密钥不同，因此不同运行的 APK 不能直接覆盖安装。
需要先卸载旧版才能安装新包，卸载会清除本地数据。要支持持续覆盖升级，需另行配置固定发布签名。

## 本次升级

- 从 Dart 2 迁移到 Dart 3，更新依赖约束和锁文件。
- 移除未使用且不支持空安全的 `gbk2utf8`；显式声明缓存实现使用的依赖。
- Android 改用声明式 Flutter Gradle 插件和 AGP 9 内置 Kotlin；保留 Flutter 3.47 仍需要的旧 AGP DSL 兼容开关。
- 更新图片分享、视频控制器和图片变换 API，重新生成 MobX 代码。

版本来源：[Flutter SDK archive](https://docs.flutter.dev/install/archive)。
