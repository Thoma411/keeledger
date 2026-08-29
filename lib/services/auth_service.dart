/*
 * @Author: Thoma4
 * @Date: 2026-03-21 18:50:58
 * @LastEditTime: 2026-08-28 22:40:57
 * @Description: 解锁与认证
 */

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;

import 'security_service.dart';
import 'settings_service.dart';
import 'storage_service.dart';
import 'webdav_service.dart';

class AuthService {
  final StorageService _storage = StorageService();
  final SecurityService _sec = SecurityService();

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
      final dkString = _sec.decrypt(edkM, mk); // 此时解出的是 Base64 格式的 DK
      final dk = enc.Key(base64.decode(dkString));

      // 4. 验证DK是否正确(通过解密EVB)
      final verifyResult = _sec.decrypt(evb, dk);

      if (verifyResult == "VAULT_READY") {
        // 5. 验证通过, 把DK存入内存供全应用使用
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
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("解锁失败: $e"); // 可能是解密报错（密码错）
      return false;
    }
  }

  // 创建新保险箱: 生成随机原语、信封包装并持久化, 返回恢复密钥(RK)
  Future<String> createVault(String password) async {
    // 1. 触发建库
    await _storage.database;

    // 2. 生成随机原语
    final salt = _sec.generateRandomBytes(32); // 32字节salt
    final dkBytes = _sec.generateRandomBytes(32); // 32字节数据密钥(DK)
    final rkBytes = _sec.generateRandomBytes(32); // 32字节恢复密钥(RK)
    final dk = enc.Key(dkBytes);
    final rk = enc.Key(rkBytes);
    final rkString = base64.encode(rkBytes); // 用户的救命稻草

    // 3. 派生主密钥(MK)并执行"信封包装"加密
    final mk = _sec.deriveMasterKey(password, salt);
    final edkM = _sec.encrypt(base64.encode(dkBytes), mk); // MK锁DK
    final edkR = _sec.encrypt(base64.encode(dkBytes), rk); // RK锁DK
    final evb = _sec.encrypt("VAULT_READY", dk); // DK锁验证块
    final erk = _sec.encrypt(rkString, dk); // DK锁RK(供日后查看)

    // 4. 持久化到system_metadata
    await _storage.saveMetadata('master_salt', base64.encode(salt));
    await _storage.saveMetadata('edk_m', edkM);
    await _storage.saveMetadata('edk_r', edkR);
    await _storage.saveMetadata('evb', evb);
    await _storage.saveMetadata('erk', erk);

    // 5. 激活内存密钥
    _sec.setDK(dk);
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
    final dkBase64 = base64.encode(dk.bytes);
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
      final dkString = _sec.decrypt(edkR, enc.Key(rawRkBytes));
      final dk = enc.Key(base64.decode(dkString));
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
    final dkBase64 = base64.encode(dk.bytes);
    final newEdkM = _sec.encrypt(dkBase64, newMk);
    await _storage.saveMetadata('master_salt', base64.encode(newSalt));
    await _storage.saveMetadata('edk_m', newEdkM);
    // 轮转恢复密钥, 返回新的RK
    return _sec.rotateRecoveryKey();
  }
}
