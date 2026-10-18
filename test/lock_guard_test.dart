/*
 * @Author: Thoma4
 * @Date: 2026-09-17 00:51:34
 * @LastEditTime: 2026-10-18 23:02:18
 * @Description: 锁定守卫判定测试
 */

import 'package:flutter_test/flutter_test.dart';

import 'package:keeledger/services/auth_service.dart';
import 'package:keeledger/services/security_service.dart';
import 'package:keeledger/services/storage_service.dart';
import 'helpers/vault_fixture.dart';

void main() {
  useVaultFixture(
    tempPrefix: 'keeledger_guard_',
    dbFileName: 'guard_vault.db',
    createVault: false,
  );

  setUp(() async {
    // 用例语义是"本地有库": 库文件存在但连接未打开
    await StorageService().closeDatabase();
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
