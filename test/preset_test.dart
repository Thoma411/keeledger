/*
 * @Author: Thoma4
 * @Date: 2026-10-09 22:58:20
 * @LastEditTime: 2026-10-09 23:27:41
 * @Description: 常用信息测试
 */

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:keeledger/models/preset.dart';
import 'package:keeledger/services/auth_service.dart';
import 'package:keeledger/services/security_service.dart';
import 'package:keeledger/services/settings_service.dart';
import 'package:keeledger/services/storage_service.dart';

void main() {
  group('PresetKind', () {
    test('code/label 映射, 未知 code 兜底', () {
      expect(PresetKind.nickname.code, 'nickname');
      expect(PresetKind.password.code, 'password');
      expect(PresetKind.email.code, 'email');
      expect(PresetKind.phone.code, 'phone');
      expect(PresetKind.email.label, '绑定邮箱');
      expect(PresetKind.fromCode('password'), PresetKind.password);
      expect(PresetKind.fromCode('已废弃的类型'), PresetKind.nickname);
    });
  });

  group('Preset 模型', () {
    setUp(() => SecurityService().setDK(Uint8List(32)));
    tearDown(() => SecurityService().clearKeys());

    test('toMap 只加密内容, 名称与类型保持明文', () {
      final preset = Preset(
        id: 'p1',
        name: '  Gmail_1  ',
        kind: PresetKind.email,
        value: '  xxx1@gmail.com  ',
        lastModified: '2026-10-09T10:00:00',
      );
      final map = preset.toMap();

      expect(map['id'], 'p1');
      expect(map['name'], 'Gmail_1'); // 去空白 + 明文
      expect(map['kind'], 'email');
      expect(map['value'], isNot('xxx1@gmail.com')); // 内容已加密
      expect(map['value'].toString(), startsWith('v2:'));
      // 非密码类型: 内容首尾空白一并去掉
      expect(Preset.fromMap(map).value, 'xxx1@gmail.com');
    });

    test('内容规范: 密码保留首尾空白, 其余类型去除', () {
      Preset make(PresetKind kind) => Preset(
        id: 'p1',
        name: '  待清理  ',
        kind: kind,
        value: '  13800138000  ',
        lastModified: '2026-10-09T10:00:00',
      );

      expect(make(PresetKind.password).value, '  13800138000  '); // 密码原样
      expect(make(PresetKind.phone).value, '13800138000');
      expect(make(PresetKind.email).value, '13800138000');
      expect(make(PresetKind.phone).name, '待清理'); // 名称一律去空白
    });

    test('fromMap 还原明文内容与类型', () {
      final map = Preset(
        id: 'p1',
        name: 'Gmail_1',
        kind: PresetKind.email,
        value: 'xxx1@gmail.com',
        lastModified: '2026-10-09T10:00:00',
      ).toMap();

      final back = Preset.fromMap(map);
      expect(back.id, 'p1');
      expect(back.name, 'Gmail_1');
      expect(back.kind, PresetKind.email);
      expect(back.value, 'xxx1@gmail.com');
      expect(back.lastModified, '2026-10-09T10:00:00');
    });

    test('密钥不对时不抛异常, 内容标记为解密失败', () {
      final map = Preset(
        id: 'p1',
        name: 'Gmail_1',
        kind: PresetKind.email,
        value: 'xxx1@gmail.com',
        lastModified: '',
      ).toMap();

      SecurityService().setDK(Uint8List.fromList(List.filled(32, 7)));
      expect(Preset.fromMap(map).value, '[解密失败]');
    });
  });

  group('存取', () {
    late Directory tempDir;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('keeledger_preset_');
      StorageService.overrideDbPath = p.join(tempDir.path, 'test_vault.db');
      SharedPreferences.setMockInitialValues({});
      await SettingsService().init();
      SecurityService().clearKeys();
      await AuthService().createVault('password123');
    });

    tearDown(() async {
      await StorageService().closeDatabase();
      StorageService.overrideDbPath = null;
      SecurityService().clearKeys();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Preset sample(String id, String name) => Preset(
      id: id,
      name: name,
      kind: PresetKind.email,
      value: '$name@gmail.com',
      lastModified: '2026-10-09T10:00:00',
    );

    test('新增/读取/覆盖保存/删除, 且推进同步修订号', () async {
      final storage = StorageService();
      int revision() => int.parse(
        SettingsService().get('local_revision', defaultValue: '0')!,
      );

      expect(await storage.getAllPresets(), isEmpty);

      final rev0 = revision();
      await storage.savePreset(sample('p1', 'Gmail_1'));
      expect(revision(), rev0 + 1); // 写操作推进修订号

      final list = await storage.getAllPresets();
      expect(list.length, 1);
      expect(list.single.name, 'Gmail_1');
      expect(list.single.kind, PresetKind.email);
      expect(list.single.value, 'Gmail_1@gmail.com');

      // 落库的 content 是密文
      final db = await storage.database;
      final row = (await db.query('presets')).single;
      expect(row['value'], isNot('Gmail_1@gmail.com'));
      expect(row['value'].toString(), startsWith('v2:'));

      // 同 id 再保存 = 覆盖(改名改内容)
      await storage.savePreset(sample('p1', 'Gmail_2'));
      final updated = await storage.getAllPresets();
      expect(updated.length, 1);
      expect(updated.single.name, 'Gmail_2');
      expect(updated.single.value, 'Gmail_2@gmail.com');

      await storage.deletePreset('p1');
      expect(await storage.getAllPresets(), isEmpty);
    });

    test('名称查重不分大小写, 且可排除自身', () async {
      final storage = StorageService();
      await storage.savePreset(sample('p1', 'Gmail_1'));

      expect(await storage.isPresetNameExists('gmail_1'), isTrue);
      expect(await storage.isPresetNameExists('  GMAIL_1  '), isTrue);
      expect(await storage.isPresetNameExists('Gmail_2'), isFalse);
      expect(
        await storage.isPresetNameExists('Gmail_1', excludeId: 'p1'),
        isFalse,
      );
    });

    test('重开库后仍可读回(表结构幂等建立)', () async {
      final storage = StorageService();
      await storage.savePreset(sample('p1', 'Gmail_1'));
      await storage.closeDatabase(); // 模拟重新打开

      final again = await storage.getAllPresets();
      expect(again.single.value, 'Gmail_1@gmail.com');
    });
  });
}
