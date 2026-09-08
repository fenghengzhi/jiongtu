import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_update_service.dart';

String _errorMessage(Object error) {
  if (error is UpdateException) return error.message;
  if (error is PlatformException) return error.message ?? '无法安装更新，请重试。';
  if (error is MissingPluginException) return '当前平台暂不支持应用内更新。';
  return '更新失败，请稍后重试。';
}

class AppUpdateTile extends StatefulWidget {
  const AppUpdateTile({super.key, this.service});
  final AppUpdateService? service;

  @override
  State<AppUpdateTile> createState() => _AppUpdateTileState();
}

class _AppUpdateTileState extends State<AppUpdateTile> {
  late final _service = widget.service ?? AppUpdateService();
  InstalledAppInfo? _current;
  bool _checking = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final current = await _service.installer.getInstalledApp();
      if (mounted) setState(() => _current = current);
    } catch (_) {
      // Show actionable failures when the user actually checks for updates.
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = null;
    });
    try {
      final current = await _service.installer.getInstalledApp();
      if (!mounted) return;
      setState(() => _current = current);
      final release = await _service.checkForUpdate(current);
      if (!mounted) return;
      setState(() => _checking = false);
      if (release == null) {
        setState(() => _status = '已是最新版本');
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _UpdateDialog(service: _service, release: release),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _status = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: const Text('检查更新'),
    subtitle: Text(
      [
        if (_current != null) '当前版本 ${_current!.label}',
        if (_checking)
          '正在检查 GitHub Releases…'
        else
          _status ?? '通过 GitHub Releases 获取更新',
      ].join('\n'),
    ),
    trailing: _checking
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.system_update),
    onTap: _checking ? null : _check,
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.service, required this.release});
  final AppUpdateService service;
  final AppRelease release;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  File? _apk;
  bool _busy = false;
  bool _needsPermission = false;
  bool _installerOpened = false;
  double? _progress;
  String? _message;

  @override
  void dispose() {
    widget.service.cancelDownload();
    // Keep verified APKs available to the external installer after this dialog
    // closes. Android cleans cache files; native code also prunes old downloads.
    super.dispose();
  }

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      _apk ??= await widget.service.download(widget.release, (received, total) {
        if (mounted) setState(() => _progress = received / total);
      });
      if (!mounted) return;
      if (!await widget.service.installer.canInstall()) {
        if (!mounted) return;
        if (!_needsPermission) {
          setState(() {
            _needsPermission = true;
            _message = '安装包已校验。请允许本应用安装更新，授权后会继续打开系统安装器。';
          });
          return;
        }
        if (!await widget.service.installer.requestPermission()) {
          if (mounted) {
            setState(() => _message = '尚未允许安装。点击“允许安装”后，在系统设置中开启权限。');
          }
          return;
        }
      }
      if (!mounted) return;
      await widget.service.installer.install(_apk!, widget.release);
      if (mounted) {
        setState(() {
          _needsPermission = false;
          _installerOpened = true;
          _message = '已打开系统安装器，请在系统界面确认安装。取消后可再次安装。';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    return AlertDialog(
      title: const Text('发现新版本'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${release.label} · ${(release.size / 1024 / 1024).toStringAsFixed(1)} MB',
              ),
              if (release.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  release.notes.length > 4000
                      ? '${release.notes.substring(0, 4000)}…'
                      : release.notes,
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _apk == null ? _progress : null),
                const SizedBox(height: 8),
                Text(
                  _apk != null
                      ? '正在准备安装…'
                      : _progress == 1
                      ? '正在校验安装包…'
                      : '正在下载 ${((_progress ?? 0) * 100).toStringAsFixed(0)}%',
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_busy && _apk == null ? '取消下载' : '关闭'),
        ),
        FilledButton(
          onPressed: _busy ? null : _update,
          child: Text(
            _needsPermission
                ? '允许安装'
                : _installerOpened
                ? '再次安装'
                : _apk != null
                ? '安装更新'
                : '下载并安装',
          ),
        ),
      ],
    );
  }
}
