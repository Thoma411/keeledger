/*
 * @Author: Thoma4
 * @Date: 2026-09-20 22:09:17
 * @LastEditTime: 2026-09-20 22:21:05
 * @Description: 便携设置文件(settings.json)后端测试
 */

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keeledger/services/settings_service.dart';
import 'package:keeledger/utils/app_paths.dart';

void main() {
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
}
