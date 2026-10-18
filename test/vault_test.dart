/*
 * @Author: Thoma4
 * @Date: 2026-10-18 23:06:28
 * @LastEditTime: 2026-10-18 23:17:29
 * @Description: 保险柜测试(生命周期: 建库/解锁/改密/找回 + 锁定守卫判定)
 */

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:keeledger/models/account.dart';
import 'package:keeledger/services/auth_service.dart';
import 'package:keeledger/services/security_service.dart';
import 'package:keeledger/services/settings_service.dart';
import 'package:keeledger/services/storage_service.dart';
import 'helpers/vault_fixture.dart';

void main() {
  group('生命周期', () {
    useVaultFixture();

    test('创建保险箱后: 正确密码可解锁, 错误密码被拒绝', () async {
      final auth = AuthService();

      expect(vaultRecoveryKey, isNotEmpty); // 恢复密钥已生成
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
      final String rk = vaultRecoveryKey;

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

    test('ensure-column: 打开库即自动补列, 星标字段保存与读取一致', () async {
      final storage = StorageService();
      // 建库(含ensure)后accounts应已存在favorite列
      final db = await storage.database;
      final info = await db.rawQuery('PRAGMA table_info(accounts)');
      final colNames = info.map((r) => r['name']).toList();
      expect(colNames, contains('favorite'));

      // 插入带星标的账户并读回(createVault已激活DK, toMap可加密)
      final acc = Account(
        id: 'fav-1',
        platform: 'GitHub',
        url: '',
        status: 1,
        name: 'n',
        userId: 'u',
        email: 'e@x.com',
        pswd: 'p',
        phone: '',
        realName: false,
        favorite: true,
        lastModified: DateTime.now().toIso8601String(),
      );
      await storage.insertAccount(acc);

      final all = await storage.getAllAccounts();
      final back = all.firstWhere((a) => a.id == 'fav-1');
      expect(back.favorite, isTrue);
      expect(back.platform, 'GitHub');
      expect(back.email, 'e@x.com'); // 敏感字段经DK解密后正常
    });

    test('v2迁移: 标记已置位时, 带MK的解锁仍会补升级 edk_m', () async {
      final storage = StorageService();
      final sec = SecurityService();

      // 构造“只用指纹解锁过”的状态: edk_m 停在v1, 但迁移标记已是true
      final String edkM = (await storage.getMetadata('edk_m'))!;
      expect(edkM.startsWith('v2:'), isTrue); // 新库本应为v2
      final List<int> body = base64.decode(edkM.split(':').last);
      await storage.saveMetadata(
        'edk_m',
        base64.encode(body.sublist(0, body.length - 16)), // 剥掉前缀与Tag即v1
      );
      await SettingsService().set('crypto_v2_upgraded', 'true');

      // 主密码解锁(会调用 upgradeCipherToV2(mk))
      sec.clearKeys();
      expect(await AuthService().verifyPassword('password123'), isTrue);

      final String after = (await storage.getMetadata('edk_m'))!;
      expect(after.startsWith('v2:'), isTrue, reason: 'edk_m 应被补升级为 v2');
    });
  });

  group('锁定守卫', () {
    useVaultFixture(
      tempPrefix: 'keeledger_guard_',
      dbFileName: 'guard_vault.db',
      createVault: false,
    );

    setUp(() async {
      // 用例语义是"本地有库": 库文件存在但连接未打开
      await StorageService().closeDatabase();
    });

    test('本地无库时不需要回退解锁页', () async {
      // 无库 + 无DK(左滑退出被系统保活重入) -> 不应弹登录页
      expect(await AuthService().needsRelock(), isFalse);
    });

    test('本地有库且已解锁时不需要回退解锁页', () async {
      await AuthService().createVault('password123');
      expect(SecurityService().currentDataKey, isNotNull); // 建库后DK在内存

      expect(await AuthService().needsRelock(), isFalse);
    });

    test('本地有库但DK已清空时需要回退解锁页', () async {
      await AuthService().createVault('password123');
      SecurityService().clearKeys(); // 模拟内存密钥已被清空
      await StorageService().closeDatabase();

      expect(await AuthService().needsRelock(), isTrue);
    });
  });
}
