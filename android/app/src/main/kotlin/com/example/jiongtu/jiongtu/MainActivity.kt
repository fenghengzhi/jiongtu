package com.example.jiongtu

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val updateExecutor = Executors.newSingleThreadExecutor()
    private var permissionResult: MethodChannel.Result? = null
    private val permissionRequestCode = 7101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.jiongtu/updates")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getAppInfo" -> {
                            val info = installedPackage()
                            result.success(mapOf(
                                "versionName" to (info.versionName ?: ""),
                                "versionCode" to versionCode(info),
                                "sdkInt" to Build.VERSION.SDK_INT,
                                // Match the installed process architecture, including 32-bit
                                // apps running on 64-bit devices (Flutter adds ABI offsets).
                                "abis" to (if (Process.is64Bit()) Build.SUPPORTED_64_BIT_ABIS
                                    else Build.SUPPORTED_32_BIT_ABIS).toList(),
                            ))
                        }
                        "getDownloadDirectory" -> {
                            val directory = File(cacheDir, "updates").apply { mkdirs() }
                            // Retain recent APKs because the system installer may still
                            // be reading them after the Flutter dialog has closed.
                            directory.listFiles()?.filter {
                                System.currentTimeMillis() - it.lastModified() > 24 * 60 * 60 * 1000L
                            }?.forEach { it.deleteRecursively() }
                            result.success(directory.path)
                        }
                        "canInstallPackages" -> result.success(canInstallPackages())
                        "requestInstallPermission" -> requestInstallPermission(result)
                        "installApk" -> {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("缺少安装包路径。")
                            val expectedCode = call.argument<Number>("versionCode")?.toLong()
                                ?: throw IllegalArgumentException("缺少更新版本号。")
                            val expectedName = call.argument<String>("versionName")
                                ?: throw IllegalArgumentException("缺少更新版本名称。")
                            updateExecutor.execute {
                                try {
                                    val apk = validateApk(path, expectedCode, expectedName)
                                    runOnUiThread {
                                        try {
                                            check(canInstallPackages()) { "请先允许本应用安装更新。" }
                                            val uri = FileProvider.getUriForFile(
                                                this, "$packageName.updates", apk,
                                            )
                                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                                setDataAndType(uri, "application/vnd.android.package-archive")
                                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                                clipData = ClipData.newRawUri("APK", uri)
                                            }
                                            startActivity(intent)
                                            // This only confirms launching the installer, not installation.
                                            result.success(null)
                                        } catch (_: ActivityNotFoundException) {
                                            result.error("installer_unavailable", "此设备没有可用的系统安装器。", null)
                                        } catch (error: Exception) {
                                            result.error("install_failed", error.message ?: "无法打开安装器。", null)
                                        }
                                    }
                                } catch (error: Exception) {
                                    runOnUiThread {
                                        result.error("invalid_apk", error.message ?: "安装包验证失败，请重新下载。", null)
                                    }
                                }
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("update_failed", error.message ?: "更新操作失败。", null)
                }
            }
    }

    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    @Suppress("DEPRECATION")
    private fun requestInstallPermission(result: MethodChannel.Result) {
        if (canInstallPackages()) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("permission_pending", "请先完成当前安装授权。", null)
            return
        }
        permissionResult = result
        try {
            startActivityForResult(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")),
                permissionRequestCode,
            )
        } catch (error: Exception) {
            permissionResult = null
            result.error("permission_unavailable", "无法打开安装权限设置，请在系统设置中允许本应用安装未知应用。", null)
        }
    }

    @Deprecated("Required for the install-permission settings result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == permissionRequestCode) {
            permissionResult?.success(canInstallPackages())
            permissionResult = null
        }
    }

    @Suppress("DEPRECATION")
    private fun installedPackage(): PackageInfo = packageManager.getPackageInfo(packageName, signatureFlags())

    @Suppress("DEPRECATION")
    private fun signatureFlags(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
        PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
        info.longVersionCode else info.versionCode.toLong()

    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo): Set<String> =
        (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.signingInfo?.apkContentsSigners
            else info.signatures)?.map { it.toCharsString() }?.toSet() ?: emptySet()

    @Suppress("DEPRECATION")
    private fun validateApk(path: String, expectedCode: Long, expectedName: String): File {
        val apk = File(path).canonicalFile
        val root = File(cacheDir, "updates").canonicalFile
        require(apk.path.startsWith(root.path + File.separator) && apk.isFile && apk.extension == "apk") {
            "安装包不存在，请重新下载。"
        }
        val archive = packageManager.getPackageArchiveInfo(apk.path, signatureFlags())
            ?: throw IllegalArgumentException("安装包无效，请重新下载。")
        val installed = installedPackage()
        require(archive.packageName == packageName) { "安装包不属于本应用。" }
        require(versionCode(archive) == expectedCode && archive.versionName == expectedName) {
            "安装包版本与更新信息不一致，请重新检查更新。"
        }
        require(versionCode(archive) > versionCode(installed)) { "此版本不高于当前版本，无需安装。" }
        require((archive.applicationInfo?.minSdkVersion ?: Int.MAX_VALUE) <= Build.VERSION.SDK_INT) {
            "此版本不支持当前 Android 系统。"
        }
        val expectedSigners = signers(installed)
        require(expectedSigners.isNotEmpty() && signers(archive) == expectedSigners) {
            "安装包签名与当前应用不同，无法覆盖更新。请使用相同签名的发布版本。"
        }
        return apk
    }

    override fun onDestroy() {
        permissionResult?.error("activity_closed", "安装授权已中断，请重试。", null)
        permissionResult = null
        updateExecutor.shutdown()
        super.onDestroy()
    }
}
