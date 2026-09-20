/*
 * @Author: Thoma4
 * @Date: 2026-09-20 21:22:26
 * @LastEditTime: 2026-09-20 22:33:51
 * @Description: 数据落点收口
 */

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// 数据落点: Windows便携(`<exe>/data`), 其它端标准目录
class AppPaths {
  AppPaths._();

  static String? overrideRoot; // 测试注入
  static bool? overridePortable;

  static String? _root;
  static bool _portable = false;

  static bool get isInitialized => _root != null;
  static bool get isPortable => _portable;
  static String get root => _root!;

  // 本地设置文件(便携时为`<exe>/data/settings.json`)
  static String get settingsFile => p.join(root, 'settings.json');

  // exe所在目录
  static String get executableDir =>
      File(Platform.resolvedExecutable).parent.path;

  // 数据库文件(便携: `<exe>/data/keeledger.db`)
  static String get dbFile => p.join(root, 'keeledger.db');

  // 历史遗留位置
  static String get _legacyDbFile => p.join(
    executableDir,
    '.dart_tool',
    'sqflite_common_ffi',
    'databases',
    'keeledger.db',
  );

  // 平移历史位置的库(含wal/shm), 目标已存在或源不存在则不动
  @visibleForTesting
  static Future<bool> adoptLegacyDb(String from, String to) async {
    if (File(to).existsSync() || !File(from).existsSync()) return false;
    for (final String suffix in ['', '-wal', '-shm']) {
      final File old = File('$from$suffix');
      if (old.existsSync()) await old.rename('$to$suffix');
    }
    debugPrint("AppPaths: 历史数据库已平移至 $to");
    return true;
  }

  // 确定数据落点, 需在读取任何配置之前调用
  static Future<void> init() async {
    if (overrideRoot != null) {
      _root = overrideRoot;
      _portable = overridePortable ?? false;
      await Directory(_root!).create(recursive: true);
      return;
    }

    if (Platform.isWindows) {
      _portable = true; // 约定exe目录可写, 不做探测
      _root = p.join(executableDir, 'data');
      await Directory(_root!).create(recursive: true);
      await adoptLegacyDb(_legacyDbFile, dbFile);
      return;
    }

    _portable = false;
    _root = (await getApplicationSupportDirectory()).path;
    await Directory(_root!).create(recursive: true);
  }
}
