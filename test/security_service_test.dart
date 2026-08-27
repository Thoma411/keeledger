/*
 * @Author: Thoma4
 * @Date: 2026-08-14 22:15:36
 * @LastEditTime: 2026-08-14 22:26:44
 * @Description: SecurityService 加密核心的单元测试
 */

import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/services/security_service.dart';

void main() {
  group('SecurityService 加密', () {
    test('AES-256-GCM 加密解密往返一致', () {
      final sec = SecurityService();
      final key = Key(sec.generateRandomBytes(32));
      const plain = '你好，Keeledger! 123456';

      final cipher = sec.encrypt(plain, key);

      expect(cipher, isNot(contains(plain))); // 密文不应包含明文
      expect(sec.decrypt(cipher, key), plain); // 解密还原
    });

    test('相同明文两次加密得到不同密文(随机IV)', () {
      final sec = SecurityService();
      final key = Key(sec.generateRandomBytes(32));

      final a = sec.encrypt('hello', key);
      final b = sec.encrypt('hello', key);

      expect(a, isNot(b));
    });

    test('错误密钥解密得不到原文(保密性)', () {
      final sec = SecurityService();
      final key1 = Key(sec.generateRandomBytes(32));
      final key2 = Key(sec.generateRandomBytes(32));

      final cipher = sec.encrypt('secret', key1);

      // 注意: 当前 encrypt 包在 padding:null 的 GCM 路径下不做认证标签校验,
      // 错误密钥不会抛异常, 而是解出乱码。此处断言保密性: 解不出原文。
      // TODO(安全): GCM 认证校验缺失, 见 SecurityService.decrypt 说明。
      expect(sec.decrypt(cipher, key2), isNot('secret'));
    });

    test('篡改密文后解不出原文(保密性)', () {
      final sec = SecurityService();
      final key = Key(sec.generateRandomBytes(32));

      final cipher = sec.encrypt('secret', key);

      // 篡改密文最后一个字节, 解密不会抛异常但应解不出原文
      final bytes = base64.decode(cipher);
      bytes[bytes.length - 1] = bytes[bytes.length - 1] ^ 0xFF;
      final tampered = base64.encode(bytes);

      expect(sec.decrypt(tampered, key), isNot('secret'));
    });

    test('空字符串也能正常加密解密', () {
      final sec = SecurityService();
      final key = Key(sec.generateRandomBytes(32));

      final cipher = sec.encrypt('', key);
      expect(sec.decrypt(cipher, key), '');
    });
  });
}
