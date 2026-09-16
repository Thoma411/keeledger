/*
 * @Author: Thoma4
 * @Date: 2026-09-14 22:43:50
 * @LastEditTime: 2026-09-17 00:31:26
 * @Description: 深色模式(设置页"外观")测试
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keeledger/services/settings_service.dart';
import 'package:keeledger/utils/utils.dart';
import 'package:keeledger/widgets/account_ui_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 用给定的本地配置初始化设置服务, 返回解析出的深色模式设置值
  Future<String> resolveDarkMode(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    await SettingsService().init();
    return SettingsService().darkModeValue;
  }

  test('深色模式: 未设置(dark_mode 缺失)时默认浅色', () async {
    expect(await resolveDarkMode({}), 'light');
  });

  test('深色模式: 沿用 dark_mode 键的三态', () async {
    expect(await resolveDarkMode({'dark_mode': 'true'}), 'dark');
    expect(await resolveDarkMode({'dark_mode': 'false'}), 'light');
    expect(await resolveDarkMode({'dark_mode': 'system'}), 'system');
  });

  test('深色模式: setDarkMode 按 dark_mode 编码写入', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.init();

    await settings.setDarkMode('dark');
    expect(settings.get('dark_mode'), 'true');
    expect(settings.darkModeValue, 'dark');

    await settings.setDarkMode('system');
    expect(settings.get('dark_mode'), 'system');
    expect(settings.darkModeValue, 'system');

    await settings.setDarkMode('light');
    expect(settings.get('dark_mode'), 'false');
    expect(settings.darkModeValue, 'light');
  });

  test('深色模式: 字符串映射为 ThemeMode, 未知值回退浅色', () {
    expect(DarkModeUtil.toThemeMode('system'), ThemeMode.system);
    expect(DarkModeUtil.toThemeMode('light'), ThemeMode.light);
    expect(DarkModeUtil.toThemeMode('dark'), ThemeMode.dark);
    expect(DarkModeUtil.toThemeMode('whatever'), ThemeMode.light);
  });

  testWidgets('深色模式: shield icon彩蛋', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      late IconData icon;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(brightness), // 强制重建整棵树, 避免复用上一轮的元素
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (context) {
              icon = AccountUiUtils.shieldIcon(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        icon,
        brightness == Brightness.dark
            ? Icons.shield_moon_outlined
            : Icons.shield_outlined,
      );
    }
  });
}
