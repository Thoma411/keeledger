/*
 * @Author: Thoma4
 * @Date: 2026-09-16 18:02:08
 * @LastEditTime: 2026-10-18 23:02:03
 * @Description: 指纹解锁回归测试
 */

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:keeledger/services/auth_service.dart';
import 'package:keeledger/services/biometric_keystore.dart';
import 'package:keeledger/services/security_service.dart';
import 'package:keeledger/services/settings_service.dart';
import 'helpers/vault_fixture.dart';

// 假硬件密钥存储: BK放在内存里, 并可模拟"用户取消/密钥失效"等情况
class FakeBiometricKeyStore implements BiometricKeyStore {
  Uint8List? storedKey;
  BiometricAvailability availabilityValue = BiometricAvailability.available;
  BiometricKeyStatus readStatus = BiometricKeyStatus.ok;
  int deleteCount = 0;

  @override
  Future<BiometricAvailability> availability() async => availabilityValue;

  @override
  Future<BiometricKeyResult> readKey() async {
    if (readStatus != BiometricKeyStatus.ok) {
      return BiometricKeyResult(readStatus);
    }
    if (storedKey == null) {
      return const BiometricKeyResult(BiometricKeyStatus.missing);
    }
    return BiometricKeyResult(BiometricKeyStatus.ok, storedKey);
  }

  @override
  Future<bool> writeKey(Uint8List key) async {
    storedKey = Uint8List.fromList(key);
    return true;
  }

  @override
  Future<void> deleteKey() async {
    deleteCount++;
    storedKey = null;
  }
}

void main() {
  useVaultFixture(tempPrefix: 'keeledger_bio_', createVault: false);
  late AuthService auth;
  late FakeBiometricKeyStore store;

  setUp(() async {
    // SharedPreferences 的 mock 实例会被缓存, 需显式清掉上一条用例残留的指纹配置
    await SettingsService().set('bio_enabled', 'false');
    await SettingsService().set('bio_edk', '');

    auth = AuthService();
    store = FakeBiometricKeyStore();
    auth.bioKeyStore = store;
    await auth.createVault('password123'); // 建库并激活DK
  });

  test('开启指纹解锁: 硬件写入 32 字节 BK, 本机写入可解出 DK 的封装', () async {
    final dk = SecurityService().currentDataKey!;
    expect(await auth.isBiometricUsable(), isTrue);

    expect(await auth.enableBiometric(), isTrue);
    expect(auth.isBiometricEnabled(), isTrue);
    expect(store.storedKey, isNotNull);
    expect(store.storedKey!.length, 32);

    // 本机封装 = AES-GCM(DK, BK)
    final String edkB = SettingsService().get('bio_edk')!;
    final String decoded = SecurityService().decrypt(edkB, store.storedKey!);
    expect(base64.decode(decoded), dk);
  });

  test('指纹解锁: 内存密钥清空后可恢复同一个 DK', () async {
    final dk = SecurityService().currentDataKey!;
    await auth.enableBiometric();
    SecurityService().clearKeys();
    expect(SecurityService().currentDataKey, isNull);

    expect(await auth.unlockWithBiometric(), BiometricUnlockResult.success);
    expect(SecurityService().currentDataKey, dk);
  });

  test('未开启指纹解锁: 直接返回 notEnabled', () async {
    SecurityService().clearKeys();
    expect(await auth.unlockWithBiometric(), BiometricUnlockResult.notEnabled);
  });

  test('用户取消认证: 返回 canceled 且保留本机封装', () async {
    await auth.enableBiometric();
    SecurityService().clearKeys();
    store.readStatus = BiometricKeyStatus.canceled;

    expect(await auth.unlockWithBiometric(), BiometricUnlockResult.canceled);
    expect(auth.isBiometricEnabled(), isTrue); // 封装仍在, 可重试
    expect(store.storedKey, isNotNull);
    expect(SecurityService().currentDataKey, isNull);
  });

  test('硬件密钥与封装不匹配(如指纹集合被改动): 清除封装', () async {
    await auth.enableBiometric();
    SecurityService().clearKeys();
    store.storedKey = Uint8List.fromList(List<int>.filled(32, 7)); // 换成另一把 BK

    expect(await auth.unlockWithBiometric(), BiometricUnlockResult.invalidated);
    expect(auth.isBiometricEnabled(), isFalse);
    expect(store.deleteCount, 1);
  });

  test('平台报告密钥永久失效: 清除封装', () async {
    await auth.enableBiometric();
    SecurityService().clearKeys();
    store.readStatus = BiometricKeyStatus.invalidated;

    expect(await auth.unlockWithBiometric(), BiometricUnlockResult.invalidated);
    expect(auth.isBiometricEnabled(), isFalse);
  });

  test('关闭指纹解锁: 清除本机封装与硬件密钥', () async {
    await auth.enableBiometric();
    await auth.disableBiometric();

    expect(auth.isBiometricEnabled(), isFalse);
    expect(store.storedKey, isNull);
    expect(SettingsService().get('bio_edk'), isEmpty);
  });

  test('修改主密码后指纹解锁仍然有效(DK 未变)', () async {
    final dk = SecurityService().currentDataKey!;
    await auth.enableBiometric();
    expect(
      await auth.changeMasterPassword('password123', 'newpass456'),
      isTrue,
    );
    SecurityService().clearKeys();

    expect(await auth.unlockWithBiometric(), BiometricUnlockResult.success);
    expect(SecurityService().currentDataKey, dk);
  });

  test('数据库被替换(DK 改变)后: 指纹解锁失效并清除封装', () async {
    await auth.enableBiometric();
    // 重新建库生成新的 DK, 等价于"从云端下载了另一套库"
    await auth.createVault('password123');
    SecurityService().clearKeys();

    expect(await auth.unlockWithBiometric(), BiometricUnlockResult.invalidated);
    expect(auth.isBiometricEnabled(), isFalse);
  });
}
