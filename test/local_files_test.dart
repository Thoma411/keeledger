/*
 * @Author: Thoma4
 * @Date: 2026-10-18 23:04:58
 * @LastEditTime: 2026-10-18 23:15:02
 * @Description: 本地文件测试(数据落点 / 便携设置文件)
 */

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:keeledger/services/settings_service.dart';
import 'package:keeledger/utils/app_paths.dart';

void main() {
  group('数据落点', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('keeledger_paths_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('注入根目录时按注入值确定落点并建目录', () async {
      AppPaths.overrideRoot = p.join(tempDir.path, 'data');
      AppPaths.overridePortable = true;
      addTearDown(() {
        AppPaths.overrideRoot = null;
        AppPaths.overridePortable = null;
      });

      await AppPaths.init();

      expect(AppPaths.isInitialized, isTrue);
      expect(AppPaths.isPortable, isTrue);
      expect(Directory(AppPaths.root).existsSync(), isTrue);
      expect(AppPaths.settingsFile, p.join(AppPaths.root, 'settings.json'));
    });

    test('历史库一次性平移(含 wal/shm)', () async {
      final String from = p.join(tempDir.path, 'old', 'keeledger.db');
      final String to = p.join(tempDir.path, 'data', 'keeledger.db');
      await Directory(p.dirname(from)).create(recursive: true);
      await Directory(p.dirname(to)).create(recursive: true);
      await File(from).writeAsString('main');
      await File('$from-wal').writeAsString('wal');
      await File('$from-shm').writeAsString('shm');

      expect(await AppPaths.adoptLegacyDb(from, to), isTrue);
      expect(File(to).readAsStringSync(), 'main');
      expect(File('$to-wal').existsSync(), isTrue);
      expect(File('$to-shm').existsSync(), isTrue);
      expect(File(from).existsSync(), isFalse);

      // 目标已存在 → 不覆盖
      await File(from).writeAsString('again');
      expect(await AppPaths.adoptLegacyDb(from, to), isFalse);
      expect(File(to).readAsStringSync(), 'main');
    });
  });

  group('设置文件后端', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('keeledger_settings_');
      AppPaths.overrideRoot = tempDir.path;
      AppPaths.overridePortable = true;
      await AppPaths.init(); // 只有初始化后才会启用 settings.json 后端
    });

    tearDown(() async {
      AppPaths.overrideRoot = null;
      AppPaths.overridePortable = null;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('便携端写入 settings.json 并能重新载入', () async {
      final SettingsService settings = SettingsService();
      await settings.init();
      await settings.set('list_style', 'classic');
      await settings.setFontScale('large');

      final File f = File(AppPaths.settingsFile);
      expect(f.existsSync(), isTrue);

      final Map<String, dynamic> json =
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      expect(json['list_style'], 'classic');
      expect(json['font_scale'], 'large');

      // 重新载入后仍可读回
      await settings.init();
      expect(settings.get('list_style'), 'classic');
      expect(settings.fontScaleValue, 'large');
    });

    test('设置文件损坏时按空处理, 不抛异常', () async {
      await File(AppPaths.settingsFile).writeAsString('{not a json');

      final SettingsService settings = SettingsService();
      await settings.init();

      expect(settings.get('list_style'), isNull);
      expect(settings.fontScaleValue, 'normal');
    });
  });
}
