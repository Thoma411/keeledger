/*
 * @Author: Thoma4
 * @Date: 2026-03-21 17:27:11
 * @LastEditTime: 2026-08-30 23:03:48
 * @Description: 加解密方法
 */

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart' as pc;

import 'storage_service.dart';
import 'settings_service.dart';

class SecurityService {
  Uint8List? _currentDataKey; // DK应用锁定或退出时应置为null
  void setDK(Uint8List key) => _currentDataKey = key;
  Uint8List? get currentDataKey => _currentDataKey;
  void clearKeys() => _currentDataKey = null; // 清理内存

  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // v2密文前缀(带GCM认证标签); 无前缀视为v1旧格式
  static const String _v2Prefix = "v2:";

  // 生成真随机数(用于Salt, DK, RK)
  Uint8List generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  // 密钥派生函数(PBKDF2): 将MP转换为MK (返回32字节原始密钥)
  Uint8List deriveMasterKey(String password, Uint8List salt) {
    // 显式指定使用SHA256摘要和HMAC运算
    final pc.PBKDF2KeyDerivator derivator = pc.PBKDF2KeyDerivator(
      pc.HMac(pc.SHA256Digest(), 64), // 64是SHA256的块大小(Block Size)
    );
    // 设置参数：盐值、迭代次数、期望输出密钥长度(32字节=256位)
    derivator.init(pc.Pbkdf2Parameters(salt, 100000, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  // 核心加密方法 (AES-256-GCM 带认证标签)
  // 返回格式: "v2:" + Base64(IV(12字节) + Ciphertext + Tag(16字节))
  String encrypt(String plainText, Uint8List key) {
    final iv = generateRandomBytes(12); // GCM建议使用12字节IV
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        true,
        pc.AEADParameters(pc.KeyParameter(key), 128, iv, Uint8List(0)),
      );
    final input = Uint8List.fromList(utf8.encode(plainText));
    final encrypted = cipher.process(input); // process内含doFinal, 输出密文+16字节Tag
    // 将IV和密文(含Tag)合并存储
    final combined = Uint8List(iv.length + encrypted.length);
    combined.setRange(0, iv.length, iv);
    combined.setRange(iv.length, combined.length, encrypted);
    return _v2Prefix + base64.encode(combined);
  }

  // 核心解密方法: 自动识别 v1/v2
  // v2: 校验认证标签, 密钥错误或密文被篡改时抛异常(确定性拒绝)
  // v1: 无认证(与历史实现一致), 密钥正确性由调用方 EVB 验证兜底
  String decrypt(String encodedData, Uint8List key) {
    if (!encodedData.startsWith(_v2Prefix)) {
      return _decryptLegacy(encodedData, key);
    }
    final combined = base64.decode(encodedData.substring(_v2Prefix.length));
    final iv = combined.sublist(0, 12);
    final ciphertext = combined.sublist(12);
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        false,
        pc.AEADParameters(pc.KeyParameter(key), 128, iv, Uint8List(0)),
      );
    final decrypted = cipher.process(ciphertext); // doFinal校验Tag, 不匹配抛异常
    return utf8.decode(decrypted);
  }

  // 兼容旧格式(v1, 无认证标签)的解密: 复刻 encrypt 包 processBlock 循环行为
  String _decryptLegacy(String encodedData, Uint8List key) {
    final combined = base64.decode(encodedData);
    final iv = combined.sublist(0, 12);
    final ciphertext = combined.sublist(12);
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        false,
        pc.AEADParameters(pc.KeyParameter(key), 128, iv, Uint8List(0)),
      );
    final out = Uint8List(ciphertext.length);
    int offset = 0;
    while (offset < ciphertext.length) {
      offset += cipher.processBlock(ciphertext, offset, out, offset);
    }
    return utf8.decode(out, allowMalformed: true);
  }

  // 轮转恢复密钥RK(重置RK)
  Future<String> rotateRecoveryKey() async {
    final storage = StorageService();
    final dk = currentDataKey; // 此时内存中必须已经有DK(无论是解锁得来的还是找回得来的)
    if (dk == null) throw "加密环境未就绪";
    // 1. 生成全新随机RK
    final newRkBytes = generateRandomBytes(32);
    final newRkString = base64.encode(newRkBytes);
    // 2. 重新包装EDK_R(用新RK锁住DK)
    final dkBase64 = base64.encode(dk);
    final newEdkR = encrypt(dkBase64, newRkBytes);
    // 3. 重新包装ERK(用DK锁住新RK)
    final newErk = encrypt(newRkString, dk);
    // 4. 持久化到数据库
    await storage.saveMetadata('edk_r', newEdkR);
    await storage.saveMetadata('erk', newErk);
    return newRkString;
  }

  // 将旧版(v1, 无认证标签)密文就地升级为v2带认证格式(幂等)
  // 需在解锁后(DK在内存)调用; mk仅在验证主密码路径可用, 用于重包装edk_m
  Future<void> upgradeCipherToV2({Uint8List? mk}) async {
    final storage = StorageService();
    final dk = currentDataKey;
    if (dk == null) return;
    final settings = SettingsService();
    if (settings.get('crypto_v2_upgraded') == 'true') return; // 已升级

    // 1. 元数据: evb/erk用DK重包装; edk_r用从erk解出的RK重包装
    final evb = await storage.getMetadata('evb');
    if (evb != null && !evb.startsWith(_v2Prefix)) {
      await storage.saveMetadata('evb', encrypt("VAULT_READY", dk));
    }
    final erk = await storage.getMetadata('erk');
    if (erk != null && !erk.startsWith(_v2Prefix)) {
      final rkString = decrypt(erk, dk);
      await storage.saveMetadata('erk', encrypt(rkString, dk));
      final edkR = await storage.getMetadata('edk_r');
      if (edkR != null && !edkR.startsWith(_v2Prefix)) {
        final rkBytes = base64.decode(rkString);
        await storage.saveMetadata(
          'edk_r',
          encrypt(base64.encode(dk), rkBytes),
        );
      }
    }
    // 2. edk_m用MK重包装(仅验证主密码路径提供mk)
    final edkM = await storage.getMetadata('edk_m');
    if (mk != null && edkM != null && !edkM.startsWith(_v2Prefix)) {
      await storage.saveMetadata('edk_m', encrypt(base64.encode(dk), mk));
    }
    // 3. accounts表密文字段全部重加密为v2
    await _upgradeAccountsToV2();
    await settings.set('crypto_v2_upgraded', 'true');
  }

  // 将accounts表所有密文字段重加密为v2(字段先经fromMap解密为明文, 再以v2写回)
  Future<void> _upgradeAccountsToV2() async {
    final storage = StorageService();
    if (currentDataKey == null) return;
    final accounts = await storage.getAllAccounts();
    for (final acc in accounts) {
      await storage.updateAccountCipher(acc);
    }
  }
}
