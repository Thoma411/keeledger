/*
 * @Author: Thoma4
 * @Date: 2026-10-18 22:52:11
 * @LastEditTime: 2026-10-18 23:00:19
 * @Description: 测试共享夹具
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

Directory? _tempDir;
String _recoveryKey = '';

/// 当前用例的临时目录(需要在里面放文件时用)
Directory get vaultTempDir => _tempDir!;

/// 建库时返回的恢复密钥(`createVault: false` 时为空串)
String get vaultRecoveryKey => _recoveryKey;

/// 注册"每个用例独立临时保险柜"的夹具:
/// 临时目录 + 数据库落点 + 内存版配置 + 清空内存密钥 + 可选建库。
///
/// ```dart
/// void main() {
///   useVaultFixture(tempPrefix: 'keeledger_xxx_');
///   ...
/// }
/// ```
void useVaultFixture({
  String tempPrefix = 'keeledger_test_',
  String dbFileName = 'test_vault.db',
  bool createVault = true,
  String password = 'password123',
}) {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // 1. 每个用例使用独立的临时数据库文件, 不污染真实数据
    _tempDir = await Directory.systemTemp.createTemp(tempPrefix);
    StorageService.overrideDbPath = p.join(_tempDir!.path, dbFileName);
    // 2. 使用内存版 SharedPreferences, 避免读写真实本地配置
    SharedPreferences.setMockInitialValues({});
    await SettingsService().init();
    // 3. 清空上一用例残留的内存密钥
    SecurityService().clearKeys();
    // 4. 建库(需要自己控制时机的用例传 false)
    _recoveryKey = createVault ? await AuthService().createVault(password) : '';
  });

  tearDown(() async {
    await StorageService().closeDatabase();
    StorageService.overrideDbPath = null;
    SecurityService().clearKeys();
    final Directory? dir = _tempDir;
    _tempDir = null;
    if (dir != null && dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });
}
