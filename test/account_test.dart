/*
 * @Author: Thoma4
 * @Date: 2026-08-14 22:15:44
 * @LastEditTime: 2026-08-27 21:59:00
 * @Description: Account 模型 CSV 序列化单元测试
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/models/account.dart';

void main() {
  group('Account.fromCsv', () {
    test('正确解析完整13列CSV行', () {
      final acc = Account.fromCsv([
        'GitHub', 'tom', 'tom_id', 'a@b.com', 'pwd123',
        'https://github.com', '13800000000', '1995-06-15', '备注', '2019-01-01',
        '0', '工作,开发', '1',
      ]);

      expect(acc.platform, 'GitHub');
      expect(acc.name, 'tom');
      expect(acc.userId, 'tom_id');
      expect(acc.email, 'a@b.com');
      expect(acc.pswd, 'pwd123');
      expect(acc.url, 'https://github.com');
      expect(acc.phone, '13800000000');
      expect(acc.birth, DateTime(1995, 6, 15));
      expect(acc.notes, '备注');
      expect(acc.signupDate, DateTime(2019, 1, 1));
      expect(acc.realName, isFalse);
      expect(acc.tags, ['工作', '开发']);
      expect(acc.status, 1);
    });

    test('实名标记支持 1 / true / 是', () {
      for (final mark in ['1', 'true', '是']) {
        final row = List<String>.filled(13, '');
        row[10] = mark;
        final acc = Account.fromCsv(row);
        expect(acc.realName, isTrue, reason: '实名标记 "$mark" 应解析为 true');
      }
    });

    test('全空列使用默认值', () {
      final acc = Account.fromCsv(List<String>.filled(13, ''));

      expect(acc.platform, '');
      expect(acc.name, '');
      expect(acc.userId, '');
      expect(acc.status, 1); // 状态默认"使用中"
      expect(acc.realName, isFalse);
      expect(acc.tags, isEmpty);
    });
  });

  group('Account CSV 往返', () {
    test('toCsvRow 后再 fromCsv 关键字段保持一致', () {
      final acc = Account.fromCsv([
        'GitHub', 'tom', 'tom_id', 'a@b.com', 'pwd123',
        'https://github.com', '13800000000', '1995-06-15', '备注', '2019-01-01',
        '1', '工作,开发', '2',
      ]);

      final round = Account.fromCsv(acc.toCsvRow());

      expect(round.platform, acc.platform);
      expect(round.name, acc.name);
      expect(round.userId, acc.userId);
      expect(round.email, acc.email);
      expect(round.pswd, acc.pswd);
      expect(round.url, acc.url);
      expect(round.phone, acc.phone);
      expect(round.birth, acc.birth);
      expect(round.notes, acc.notes);
      expect(round.signupDate, acc.signupDate);
      expect(round.realName, acc.realName);
      expect(round.tags, acc.tags);
      expect(round.status, acc.status);
    });
  });
}
