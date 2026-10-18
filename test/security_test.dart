/*
 * @Author: Thoma4
 * @Date: 2026-10-18 23:05:32
 * @LastEditTime: 2026-10-18 23:16:16
 * @Description: 加密测试(加解密单元 / 修复前无认证标签的缺口对照)
 */

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:keeledger/services/security_service.dart';

// v1为修复前的存储格式(无前缀无Tag), v2为修复后的格式(带16字节认证标签)
// 构造修复前的v1格式密文: Base64(IV + 密文), 无前缀无Tag
String _makeV1(SecurityService sec, Uint8List key, String plain) {
  final v2 = sec.encrypt(plain, key);
  final body = base64.decode(v2.substring(3)); // 去掉"v2:"前缀
  return base64.encode(body.sublist(0, body.length - 16)); // 去掉16字节Tag
}

void main() {
  group('加密', () {
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

  // 这些用例故意用"修复前的逻辑路径"复现旧问题, 用于直观展示漏洞危害
  group('演示: 修复前(无认证标签)的安全缺口', () {
    test('旧行为: 错误密钥静默解出乱码, 不抛异常(无法区分密码对不对)', () {
      final sec = SecurityService();
      final realKey = sec.generateRandomBytes(32);
      final wrongKey = sec.generateRandomBytes(32);

      // 修复前的存储格式
      final v1 = _makeV1(sec, realKey, '我的密码是 Secret123');
      // 修复后的存储格式
      final v2 = sec.encrypt('我的密码是 Secret123', realKey);

      // ── 旧行为: 输入错误密钥, 应用"毫无反应"地返回乱码 ──
      final garbage = sec.decrypt(v1, wrongKey);
      expect(garbage, isNot('我的密码是 Secret123'));
      // 关键: 它没有抛任何异常, 上层代码无法据此判断"密码错了"
      // 后果: 若把乱码当结果存库, 就是当年"错误RK被接受→数据永久损坏"的根源

      // ── 对比: 同一场景在v2下立即抛异常 ──
      expect(() => sec.decrypt(v2, wrongKey), throwsA(isA<Object>()));
    });

    test('旧行为: 篡改密文一个字节, 静默解出乱码(数据损坏无法被察觉)', () {
      final sec = SecurityService();
      final key = sec.generateRandomBytes(32);

      final v1 = _makeV1(sec, key, '银行卡余额: 1000000');
      final v2 = sec.encrypt('银行卡余额: 1000000', key);

      // 篡改v1密文最后一个字节(模拟磁盘损坏/恶意篡改)
      final v1Bytes = base64.decode(v1).toList();
      v1Bytes[v1Bytes.length - 1] ^= 0x01;
      final tamperedV1 = base64.encode(v1Bytes);

      // ── 旧行为: 解出乱码, 无任何报错(数据被破坏却浑然不知) ──
      final corrupted = sec.decrypt(tamperedV1, key);
      expect(corrupted, isNot('银行卡余额: 1000000'));

      // ── 对比: v2格式下篡改立即抛异常 ──
      final v2Bytes = base64.decode(v2.substring(3)).toList();
      v2Bytes[v2Bytes.length - 1] ^= 0x01;
      expect(
        () => sec.decrypt('v2:${base64.encode(v2Bytes)}', key),
        throwsA(isA<Object>()),
      );
    });
  });
}
