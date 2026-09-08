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
Release 构建必须使用固定发布签名；缺少签名配置会直接失败，不会回退到开发签名。
本地可通过未提交的 `android/key.properties` 提供 `storeFile`（绝对路径）、`storePassword`、`keyAlias`、`keyPassword`，也可使用下文对应的环境变量。Debug 构建不受影响。

## GitHub 自动发布

每次 push 到 `master` 都会触发 [Android Release](.github/workflows/android-release.yml)：

1. 从 `.fvmrc` 安装 Flutter，准备 Java 17 和 Android 构建工具。
2. 安装锁定依赖、生成 MobX 代码，运行静态检查和页面测试。
3. 使用固定发布密钥构建 ARMv7、ARM64、x86_64 三种 release APK，以工作流运行序号作为构建号。
4. 验证三个 APK 的签名有效，且证书 SHA-256 均匹配仓库中的 `android/release-signing-cert.sha256`。
5. 将 APK、`SHA256SUMS` 和 `SIGNING_CERT_SHA256` 上传到 [GitHub Releases](https://github.com/fenghengzhi/jiongtu/releases)，并在 Actions 中保留 14 天的构建附件。

标签格式为 `android-<run_id>-<run_attempt>`，指向实际构建的提交；重跑使用新标签，保留上一次的发布产物。也可在 Actions 页面选择 `master` 手动运行。
发布使用工作流自带的 `GITHUB_TOKEN`，无需额外配置个人访问令牌。

### 固定发布签名

仓库 Actions Secrets 使用以下配置（已配置在当前仓库）：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 固定发布 keystore 的 Base64 内容 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 发布密钥别名 |
| `ANDROID_KEY_PASSWORD` | 发布密钥密码 |

工作流只在签名步骤中将 keystore 还原到临时目录，并在退出时删除；不缓存或上传私钥。
本地使用环境变量时，将 keystore 路径设置为 `ANDROID_KEYSTORE_PATH`，其余三个变量名与 Secrets 一致。
私钥和密码需另存一份安全备份；不要提交 keystore 或 `key.properties`，也不要为新版本重新生成密钥。

使用固定签名后，同一架构的后续新构建可覆盖升级并保留应用数据。
从此前随机开发签名版本切换时，仍需先卸载旧版一次（会清除本地数据）。
重跑历史任务不会增加构建号；需要更新版本时，应运行最新 `master` 的新工作流。

## 本次升级

- 从 Dart 2 迁移到 Dart 3，更新依赖约束和锁文件。
- 移除未使用且不支持空安全的 `gbk2utf8`；显式声明缓存实现使用的依赖。
- Android 改用声明式 Flutter Gradle 插件和 AGP 9 内置 Kotlin；保留 Flutter 3.47 仍需要的旧 AGP DSL 兼容开关。
- 更新图片分享、视频控制器和图片变换 API，重新生成 MobX 代码。

版本来源：[Flutter SDK archive](https://docs.flutter.dev/install/archive)。
