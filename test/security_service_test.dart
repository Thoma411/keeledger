/*
 * @Author: Thoma4
 * @Date: 2026-08-14 22:15:36
 * @LastEditTime: 2026-08-30 22:59:05
 * @Description: SecurityService加密单元测试
 */

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/services/security_service.dart';

void main() {
  group('SecurityService 加密', () {
    test('AES-256-GCM 加密解密往返一致', () {
      final sec = SecurityService();
      final key = sec.generateRandomBytes(32);
      const plain = '你好，Keeledger! 123456';

      final cipher = sec.encrypt(plain, key);

      expect(cipher, startsWith('v2:')); // 新格式带版本前缀
      expect(cipher, isNot(contains(plain))); // 密文不应包含明文
      expect(sec.decrypt(cipher, key), plain); // 解密还原
    });

    test('相同明文两次加密得到不同密文(随机IV)', () {
      final sec = SecurityService();
      final key = sec.generateRandomBytes(32);

      final a = sec.encrypt('hello', key);
      final b = sec.encrypt('hello', key);

      expect(a, isNot(b));
    });

    test('错误密钥解密直接抛异常(GCM认证标签校验)', () {
      final sec = SecurityService();
      final key1 = sec.generateRandomBytes(32);
      final key2 = sec.generateRandomBytes(32);

      final cipher = sec.encrypt('secret', key1);

      // v2带认证标签: 错误密钥无法通过标签校验, 必须抛异常(不再是乱码)
      expect(() => sec.decrypt(cipher, key2), throwsA(isA<Object>()));
    });

    test('篡改密文后解密直接抛异常(GCM认证标签校验)', () {
      final sec = SecurityService();
      final key = sec.generateRandomBytes(32);

      final cipher = sec.encrypt('secret', key);

      // 篡改密文最后一个字节(位于Tag区), 解密必须抛异常
      final body = base64.decode(cipher.substring(3));
      body[body.length - 1] = body[body.length - 1] ^ 0xFF;
      final tampered = 'v2:${base64.encode(body)}';

      expect(() => sec.decrypt(tampered, key), throwsA(isA<Object>()));
    });

    test('空字符串也能正常加密解密', () {
      final sec = SecurityService();
      final key = sec.generateRandomBytes(32);

      final cipher = sec.encrypt('', key);
      expect(sec.decrypt(cipher, key), '');
    });

    test('兼容旧格式(v1无标签): 正确密钥可解', () {
      final sec = SecurityService();
      final key = sec.generateRandomBytes(32);

      // 从v2密文剥离前缀与16字节Tag, 即得到v1格式: Base64(IV+密文)
      final v2 = sec.encrypt('legacy-data', key);
      final body = base64.decode(v2.substring(3));
      final v1 = base64.encode(body.sublist(0, body.length - 16));

      expect(sec.decrypt(v1, key), 'legacy-data'); // v1兼容路径可解
    });

    test('兼容旧格式(v1): 错误密钥不抛异常, 解出乱码(历史行为)', () {
      final sec = SecurityService();
      final key = sec.generateRandomBytes(32);
      final wrongKey = sec.generateRandomBytes(32);

      final v2 = sec.encrypt('legacy-data', key);
      final body = base64.decode(v2.substring(3));
      final v1 = base64.encode(body.sublist(0, body.length - 16));

      expect(sec.decrypt(v1, wrongKey), isNot('legacy-data'));
    });
  });
}
