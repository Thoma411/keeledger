/*
 * @Author: Thoma4
 * @Date: 2026-09-03 21:34:47
 * @LastEditTime: 2026-09-03 23:40:54
 * @Description: CSV表头映射单元测试
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/services/account_csv_mapper.dart';

Map<String, int> _idx(List<String> header) => parseCsvHeader(header).index;

void main() {
  group('csvHeader(导出表头)', () {
    test('导出表头=规范列名(注册表顺序)', () {
      expect(csvHeader(), [
        'platform',
        'name',
        'user_id',
        'email',
        'pswd',
        'url',
        'phone',
        'birth',
        'notes',
        'signup_date',
        'real_name',
        'tags',
        'status',
        'favorite',
      ]);
    });
  });

  group('parseCsvHeader', () {
    test('乱序表头按列名建立映射(与顺序无关)', () {
      final idx = _idx(['status', 'platform', 'tags', 'name', 'email']);
      expect(idx['platform'], 1);
      expect(idx['status'], 0);
      expect(idx['tags'], 2);
      expect(idx['name'], 3);
      expect(idx['email'], 4);
    });

    test('大小写与旧版别名兼容', () {
      // 旧版导出表头(混合大小写 + tag单数)
      final idx = _idx([
        'platform',
        'name',
        'USER_ID',
        'EMAIL',
        'PSWD',
        'url',
        'PHONE',
        'birth',
        'notes',
        'signup_date',
        'real_name',
        'tag',
        'status',
      ]);
      expect(idx['user_id'], 2);
      expect(idx['email'], 3);
      expect(idx['pswd'], 4);
      expect(idx['phone'], 6);
      expect(idx['tags'], 11); // tag → tags
    });

    test('缺必填列platform->抛CsvFormatException', () {
      expect(() => _idx(['name', 'email']), throwsA(isA<CsvFormatException>()));
    });

    test('重复列->抛CsvFormatException', () {
      expect(
        () => _idx(['platform', 'name', 'platform']),
        throwsA(isA<CsvFormatException>()),
      );
    });

    test('未知列被忽略并计数', () {
      final r = parseCsvHeader(['platform', 'name', 'weird_col', 'notes']);
      expect(r.index['platform'], 0);
      expect(r.ignoredColumns, 1);
    });
  });

  group('accountFromCsvRow', () {
    test('乱序表头行解析正确', () {
      final idx = _idx([
        'status',
        'platform',
        'tags',
        'birth',
        'real_name',
        'name',
        'email',
        'notes',
        'user_id',
        'url',
        'pswd',
        'phone',
        'signup_date',
      ]);
      final row = [
        '2', // status
        'GitHub', // platform
        '工作,开发', // tags
        '1995-06-15', // birth
        '1', // real_name
        'tom', // name
        'a@b.com', // email
        '备注', // notes
        'tom_id', // user_id
        'https://github.com', // url
        'pwd123', // pswd
        '13800000000', // phone
        '2019-01-01', // signup_date
      ];
      final acc = accountFromCsvRow(row, idx)!;
      expect(acc.platform, 'GitHub');
      expect(acc.status, 2);
      expect(acc.tags, ['工作', '开发']);
      expect(acc.birth, DateTime(1995, 6, 15));
      expect(acc.realName, isTrue);
      expect(acc.name, 'tom');
      expect(acc.email, 'a@b.com');
      expect(acc.notes, '备注');
      expect(acc.userId, 'tom_id');
      expect(acc.url, 'https://github.com');
      expect(acc.pswd, 'pwd123');
      expect(acc.phone, '13800000000');
      expect(acc.signupDate, DateTime(2019, 1, 1));
      expect(acc.favorite, isFalse); // 未提供favorite列: 默认非星标
    });

    test('缺选填列->使用默认值', () {
      final idx = _idx(['platform', 'name']);
      final acc = accountFromCsvRow(['GitHub', 'tom'], idx)!;
      expect(acc.platform, 'GitHub');
      expect(acc.name, 'tom');
      expect(acc.status, 1); // 默认"使用中"
      expect(acc.realName, isFalse);
      expect(acc.favorite, isFalse);
      expect(acc.tags, isEmpty);
      expect(acc.birth, isNull);
      expect(acc.email, '');
    });

    test('平台名为空->返回null(调用方按跳过处理)', () {
      final idx = _idx(['platform', 'name']);
      expect(accountFromCsvRow(['', 'tom'], idx), isNull);
      expect(accountFromCsvRow(['   ', 'tom'], idx), isNull);
    });

    test('realName兼容[1/true/是/TRUE]', () {
      final idx = _idx(['platform', 'real_name']);
      for (final mark in ['1', 'true', '是', 'TRUE']) {
        final acc = accountFromCsvRow(['GitHub', mark], idx)!;
        expect(acc.realName, isTrue, reason: '"$mark" 应解析为 true');
      }
    });
    test('favorite 兼容 1/true/是/0', () {
      final idx = _idx(['platform', 'favorite']);
      for (final mark in ['1', 'true', '是']) {
        final acc = accountFromCsvRow(['GitHub', mark], idx)!;
        expect(acc.favorite, isTrue, reason: '"$mark" 应解析为星标');
      }
      final no = accountFromCsvRow(['GitHub', '0'], idx)!;
      expect(no.favorite, isFalse);
    });
    test('非法状态/日期容错为默认值', () {
      final idx = _idx(['platform', 'status', 'birth']);
      final acc = accountFromCsvRow(['GitHub', 'abc', 'not-a-date'], idx)!;
      expect(acc.status, 1);
      expect(acc.birth, isNull);
    });

    test('标签按中英文逗号切分并去空白', () {
      final idx = _idx(['platform', 'tags']);
      final acc = accountFromCsvRow(['GitHub', '工作,开发，测试'], idx)!;
      expect(acc.tags, ['工作', '开发', '测试']);
    });
  });

  group('往返一致性', () {
    test('导出行->按导出表头再导入->关键字段一致', () {
      final header = csvHeader();
      final idx = _idx(header);
      final src = accountFromCsvRow([
        'GitHub',
        'tom',
        'tom_id',
        'a@b.com',
        'pwd123',
        'https://github.com',
        '13800000000',
        '1995-06-15',
        '备注',
        '2019-01-01',
        '1',
        '工作,开发',
        '2',
        '1', // favorite
      ], idx)!;

      final round = accountFromCsvRow(accountToCsvRow(src), idx)!;

      expect(round.platform, src.platform);
      expect(round.name, src.name);
      expect(round.userId, src.userId);
      expect(round.email, src.email);
      expect(round.pswd, src.pswd);
      expect(round.url, src.url);
      expect(round.phone, src.phone);
      expect(round.birth, src.birth);
      expect(round.notes, src.notes);
      expect(round.signupDate, src.signupDate);
      expect(round.realName, src.realName);
      expect(round.tags, src.tags);
      expect(round.status, src.status);
      expect(round.favorite, src.favorite);
    });
  });
}
