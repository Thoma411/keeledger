/*
 * @Author: Thoma4
 * @Date: 2026-03-21 18:50:58
 * @LastEditTime: 2026-09-17 13:47:20
 * @Description: 解锁与认证
 */

import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'biometric_keystore.dart';
import 'security_service.dart';
import 'settings_service.dart';
import 'storage_service.dart';
import 'webdav_service.dart';

class AuthService {
  final StorageService _storage = StorageService();
  final SecurityService _sec = SecurityService();
  BiometricKeyStore _bioStore = PluginBiometricKeyStore(); // 指纹硬件密钥存储

  // 验证主密码并解锁
  Future<bool> verifyPassword(String password) async {
    try {
      // 1. 从数据库读取解密所需的元数据
      final saltBase64 = await _storage.getMetadata('master_salt');
      final edkM = await _storage.getMetadata('edk_m');
      final evb = await _storage.getMetadata('evb');

      if (saltBase64 == null || edkM == null || evb == null) return false;

      // 2. 还原MK
      final Uint8List salt = base64.decode(saltBase64);
      final mk = _sec.deriveMasterKey(password, salt);

      // 3. 尝试用MK解开EDK_M得到DK
      final dkString = _sec.decrypt(edkM, mk); // 此时解出的是Base64格式的DK
      final dk = base64.decode(dkString);

      // 4. 验证DK是否正确(通过解密EVB)
      final verifyResult = _sec.decrypt(evb, dk);

      if (verifyResult == "VAULT_READY") {
        // 5. 验证通过: 激活保险箱(与指纹解锁路径共用收尾)
        await _activateVault(dk, mk: mk);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("解锁失败: $e"); // 可能是解密报错(密码错)
      return false;
    }
  }

  // 锁定守卫判定
  Future<bool> needsRelock() async {
    if (_sec.currentDataKey != null) return false;
    return await _storage.isDatabaseExists();
  }

  // 创建新保险箱: 生成随机原语、信封包装并持久化, 返回恢复密钥(RK)
  Future<String> createVault(String password) async {
    // 1. 触发建库
    await _storage.database;

    // 2. 生成随机原语
    final salt = _sec.generateRandomBytes(32); // 32字节salt
    final dkBytes = _sec.generateRandomBytes(32); // 32字节数据密钥(DK)
    final rkBytes = _sec.generateRandomBytes(32); // 32字节恢复密钥(RK)
    final rkString = base64.encode(rkBytes); // 用户的救命稻草

    // 3. 派生主密钥(MK)并执行"信封包装"加密
    final mk = _sec.deriveMasterKey(password, salt);
    final edkM = _sec.encrypt(base64.encode(dkBytes), mk); // MK锁DK
    final edkR = _sec.encrypt(base64.encode(dkBytes), rkBytes); // RK锁DK
    final evb = _sec.encrypt("VAULT_READY", dkBytes); // DK锁验证块
    final erk = _sec.encrypt(rkString, dkBytes); // DK锁RK(供日后查看)

    // 4. 持久化到system_metadata
    await _storage.saveMetadata('master_salt', base64.encode(salt));
    await _storage.saveMetadata('edk_m', edkM);
    await _storage.saveMetadata('edk_r', edkR);
    await _storage.saveMetadata('evb', evb);
    await _storage.saveMetadata('erk', erk);

    // 5. 激活内存密钥
    _sec.setDK(dkBytes);
    await SettingsService().set('crypto_v2_upgraded', 'true'); // 新库全为v2
    return rkString;
  }

  // 修改主密码: 验证当前密码成功后, 用新密码重新包装DK
  // 返回false表示当前主密码错误
  Future<bool> changeMasterPassword(
    String currentPassword,
    String newPassword,
  ) async {
    // 验证当前主密码(成功后会激活内存DK并加载数据库设置)
    final ok = await verifyPassword(currentPassword);
    if (!ok) return false;
    final dk = _sec.currentDataKey;
    if (dk == null) return false;

    // 生成新盐值并派生新MK, 重新包装DK
    final newSalt = _sec.generateRandomBytes(32);
    final newMk = _sec.deriveMasterKey(newPassword, newSalt);
    final dkBase64 = base64.encode(dk);
    final newEdkM = _sec.encrypt(dkBase64, newMk);

    // 持久化更新
    await _storage.saveMetadata('master_salt', base64.encode(newSalt));
    await _storage.saveMetadata('edk_m', newEdkM);
    return true;
  }

  // 用恢复密钥(RK)验证并解锁DK(供"忘记主密码"流程第一步)
  // 成功后将DK放入内存, 供resetMasterPassword使用
  Future<bool> verifyRecoveryKey(String recoveryKey) async {
    try {
      final edkR = await _storage.getMetadata('edk_r');
      final evb = await _storage.getMetadata('evb');
      if (edkR == null || evb == null) return false;
      final rawRkBytes = base64.decode(recoveryKey);
      final dkString = _sec.decrypt(edkR, rawRkBytes);
      final dk = base64.decode(dkString);
      // 用EVB验证DK是否正确(弥补GCM无认证校验: 错误RK解出的DK无法通过验证块)
      if (_sec.decrypt(evb, dk) != "VAULT_READY") return false;
      _sec.setDK(dk);
      return true;
    } catch (_) {
      return false;
    }
  }

  // 重置主密码(需先经verifyRecoveryKey激活DK):
  // 用新密码重新包装DK, 并轮转恢复密钥, 返回新的RK
  Future<String> resetMasterPassword(String newPassword) async {
    final dk = _sec.currentDataKey;
    if (dk == null) throw "加密环境未就绪";
    final newSalt = _sec.generateRandomBytes(32);
    final newMk = _sec.deriveMasterKey(newPassword, newSalt);
    final dkBase64 = base64.encode(dk);
    final newEdkM = _sec.encrypt(dkBase64, newMk);
    await _storage.saveMetadata('master_salt', base64.encode(newSalt));
    await _storage.saveMetadata('edk_m', newEdkM);
    // 轮转恢复密钥(edk_r/erk已按v2重写)
    final newRk = await _sec.rotateRecoveryKey();
    // 账户密文就地升级为v2(此时DK在内存; edk_m/edk_r/erk已是v2)
    await _sec.upgradeCipherToV2(mk: newMk);
    return newRk;
  }

  // 指纹解锁
  static const String _bioEnabledKey = 'bio_enabled';
  static const String _bioEdkKey = 'bio_edk';

  // 注入硬件密钥存储(单元测试用)
  @visibleForTesting
  set bioKeyStore(BiometricKeyStore store) => _bioStore = store;

  // 指纹解锁是否开启
  bool isBiometricEnabled() {
    final s = SettingsService();
    final String edkB = s.get(_bioEdkKey) ?? '';
    return s.get(_bioEnabledKey) == 'true' && edkB.isNotEmpty;
  }

  // 查询设备指纹可用性
  Future<BiometricAvailability> biometricAvailability() =>
      _bioStore.availability();

  // 设备指纹是否可用(硬件存在且已录入)
  Future<bool> isBiometricUsable() async =>
      await _bioStore.availability() == BiometricAvailability.available;

  // 指纹不可用原因
  Future<String?> biometricUnavailableReason() async {
    switch (await _bioStore.availability()) {
      case BiometricAvailability.available:
        return null;
      case BiometricAvailability.noHardware:
        return "本机不支持指纹识别";
      case BiometricAvailability.notEnrolled:
        return "请先在系统设置中录入指纹";
      case BiometricAvailability.hwUnavailable:
        return "指纹硬件暂时不可用";
      case BiometricAvailability.unsupported:
        return "当前平台暂不支持";
    }
  }

  // 开启指纹解锁
  Future<bool> enableBiometric() async {
    final dk = _sec.currentDataKey;
    if (dk == null) return false;
    final bk = _sec.generateRandomBytes(32); // 生成32字节硬件密钥BK
    if (!await _bioStore.writeKey(bk)) return false;
    final String edkB = _sec.encrypt(base64.encode(dk), bk);
    final s = SettingsService();
    await s.set(_bioEdkKey, edkB);
    await s.set(_bioEnabledKey, 'true');
    return true;
  }

  // 关闭指纹解锁
  Future<void> disableBiometric() async {
    final s = SettingsService();
    await s.set(_bioEnabledKey, 'false');
    await s.set(_bioEdkKey, '');
    await _bioStore.deleteKey();
  }

  // 指纹解锁
  Future<BiometricUnlockResult> unlockWithBiometric() async {
    if (!isBiometricEnabled()) return BiometricUnlockResult.notEnabled;
    final String edkB = SettingsService().get(_bioEdkKey)!;

    final BiometricKeyResult read = await _bioStore.readKey();
    switch (read.status) {
      case BiometricKeyStatus.ok:
        break;
      case BiometricKeyStatus.canceled:
        return BiometricUnlockResult.canceled;
      case BiometricKeyStatus.lockedOut:
        return BiometricUnlockResult.lockedOut;
      case BiometricKeyStatus.failed:
        return BiometricUnlockResult.failed;
      case BiometricKeyStatus.missing:
      case BiometricKeyStatus.invalidated:
        // 硬件中BK不存在或已失效时, 清除本机封装并由用户用主密码解锁后重新开启
        await disableBiometric();
        return BiometricUnlockResult.invalidated;
    }

    try {
      final Uint8List dk = Uint8List.fromList(
        base64.decode(_sec.decrypt(edkB, read.key!)),
      );
      // 与主密码路径相同的EVB校验: 防止错误密钥解出乱码被误接受
      final String? evb = await _storage.getMetadata('evb');
      if (evb == null || _sec.decrypt(evb, dk) != "VAULT_READY") {
        await disableBiometric();
        return BiometricUnlockResult.invalidated;
      }
      // 指纹路径没有MK: 仅完成不依赖MK的就地升级(edk_m由下次主密码解锁升级)
      await _activateVault(dk);
      return BiometricUnlockResult.success;
    } catch (e) {
      // 封装与当前数据库不匹配(例如主密码在其它设备修改后同步下来)
      debugPrint('指纹解锁失败: $e');
      await disableBiometric();
      return BiometricUnlockResult.invalidated;
    }
  }

  // 解锁成功后的公共收尾
  // MK仅在主密码解锁路径可用(用于重包装edk_m)
  Future<void> _activateVault(Uint8List dk, {Uint8List? mk}) async {
    _sec.setDK(dk);
    WebDavService().reset();
    await SettingsService().loadDbSettings();
    // 确保本地设备状态与数据库版本对齐
    final s = SettingsService();
    // 仅从云端下载新库重载后才对齐本地锚点
    if (s.get('need_revision_alignment') == 'true') {
      String? dbRev = s.get('local_revision');
      if (dbRev != null) {
        // 强制更新本地配置文件的快照
        await s.set('last_synced_revision', dbRev);
      }
      await s.set('need_revision_alignment', 'false');
    }
    // 就地升级旧版(v1)密文到v2带认证格式(幂等)
    await _sec.upgradeCipherToV2(mk: mk);
  }
}

// 指纹解锁结果
enum BiometricUnlockResult {
  success, // 解锁成功
  notEnabled, // 本机未开启指纹解锁
  canceled, // 用户主动取消
  lockedOut, // 尝试次数过多被系统短暂锁定
  invalidated, // 封装已失效并被清除(需用主密码解锁后重新开启)
  failed, // 其它失败(可重试)
}
