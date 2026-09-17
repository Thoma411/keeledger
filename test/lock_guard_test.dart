/*
 * @Author: Thoma4
 * @Date: 2026-09-17 00:51:34
 * @LastEditTime: 2026-09-17 13:59:26
 * @Description: 锁定守卫判定测试
 */

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:keeledger/services/auth_service.dart';
import 'package:keeledger/services/security_service.dart';
import 'package:keeledger/services/settings_service.dart';
import 'package:keeledger/services/storage_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // 每个用例独立临时库 + 内存版配置
    tempDir = await Directory.systemTemp.createTemp('keeledger_guard_');
    StorageService.overrideDbPath = p.join(tempDir.path, 'guard_vault.db');
    SharedPreferences.setMockInitialValues({});
    await SettingsService().init();
    SecurityService().clearKeys();
    await StorageService().closeDatabase();
  });

  tearDown(() async {
    await StorageService().closeDatabase();
    StorageService.overrideDbPath = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('锁定守卫: 本地无库时不需要回退解锁页', () async {
    // 无库 + 无DK(左滑退出被系统保活重入) -> 不应弹登录页
    expect(await AuthService().needsRelock(), isFalse);
  });

  test('锁定守卫: 本地有库且已解锁时不需要回退解锁页', () async {
    await AuthService().createVault('password123');
    expect(SecurityService().currentDataKey, isNotNull); // 建库后DK在内存

    expect(await AuthService().needsRelock(), isFalse);
  });

  test('锁定守卫: 本地有库但DK已清空时需要回退解锁页', () async {
    await AuthService().createVault('password123');
    SecurityService().clearKeys(); // 模拟内存密钥已被清空
    await StorageService().closeDatabase();

    expect(await AuthService().needsRelock(), isTrue);
  });
}
