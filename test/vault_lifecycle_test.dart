/*
 * @Author: Thoma4
 * @Date: 2026-08-29 17:12:55
 * @LastEditTime: 2026-08-29 17:21:21
 * @Description: 保险箱生命周期回归测试(建库/解锁/改密/找回)
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
  late String rk; // 每个用例创建保险箱时返回的恢复密钥

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // 1. 每个用例使用独立的临时数据库文件, 不污染真实数据
    tempDir = await Directory.systemTemp.createTemp('keeledger_test_');
    StorageService.overrideDbPath = p.join(tempDir.path, 'test_vault.db');
    // 2. 使用内存版 SharedPreferences, 避免读写真实本地配置
    SharedPreferences.setMockInitialValues({});
    await SettingsService().init();
    // 3. 清空上一用例残留的内存密钥
    SecurityService().clearKeys();
    // 4. 创建全新保险箱, 保存其恢复密钥供各用例使用
    rk = await AuthService().createVault('password123');
  });

  tearDown(() async {
    await StorageService().closeDatabase();
    StorageService.overrideDbPath = null;
    SecurityService().clearKeys();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('创建保险箱后: 正确密码可解锁, 错误密码被拒绝', () async {
    final auth = AuthService();

    expect(rk, isNotEmpty); // 恢复密钥已生成
    expect(await auth.verifyPassword('password123'), isTrue);
    expect(await auth.verifyPassword('wrong-pass'), isFalse);
  });

  test('修改主密码: 旧密码错误返回false, 成功后新密码生效、旧密码失效', () async {
    final auth = AuthService();

    // 旧密码错误, 返回false
    expect(
      await auth.changeMasterPassword('wrong-pass', 'newpass456'),
      isFalse,
    );
    // 旧密码正确, 修改成功
    expect(
      await auth.changeMasterPassword('password123', 'newpass456'),
      isTrue,
    );

    expect(await auth.verifyPassword('newpass456'), isTrue);
    expect(await auth.verifyPassword('password123'), isFalse);
  });

  test('忘记密码: 恢复密钥验证后重置主密码, 新RK生效、旧RK失效', () async {
    final auth = AuthService();

    // 1. 用恢复密钥解锁
    expect(await auth.verifyRecoveryKey(rk), isTrue);

    // 2. 重置主密码, 返回轮转后的新恢复密钥
    final newRk = await auth.resetMasterPassword('finalpass789');
    expect(newRk, isNotEmpty);
    expect(newRk, isNot(rk));

    // 3. 新密码生效, 旧密码失效
    expect(await auth.verifyPassword('finalpass789'), isTrue);
    expect(await auth.verifyPassword('password123'), isFalse);

    // 4. 新RK有效, 旧RK被拒绝(EVB校验保证确定性)
    expect(await auth.verifyRecoveryKey(newRk), isTrue);
    expect(await auth.verifyRecoveryKey(rk), isFalse);
  });
}
