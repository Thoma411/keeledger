/*
 * @Author: Thoma4
 * @Date: 2026-10-18 23:05:05
 * @LastEditTime: 2026-10-18 23:17:03
 * @Description: 设置项生效测试(深色模式 / 字号档位与固定尺寸缩放)
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keeledger/services/settings_service.dart';
import 'package:keeledger/utils/utils.dart';
import 'package:keeledger/widgets/account_ui_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('深色模式', () {
    // 用给定的本地配置初始化设置服务, 返回解析出的深色模式设置值
    Future<String> resolveDarkMode(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      await SettingsService().init();
      return SettingsService().darkModeValue;
    }

    test('未设置(dark_mode 缺失)时默认浅色', () async {
      expect(await resolveDarkMode({}), 'light');
    });

    test('沿用 dark_mode 键的三态', () async {
      expect(await resolveDarkMode({'dark_mode': 'true'}), 'dark');
      expect(await resolveDarkMode({'dark_mode': 'false'}), 'light');
      expect(await resolveDarkMode({'dark_mode': 'system'}), 'system');
    });

    test('setDarkMode 按 dark_mode 编码写入', () async {
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

    test('字符串映射为 ThemeMode, 未知值回退浅色', () {
      expect(DarkModeUtil.toThemeMode('system'), ThemeMode.system);
      expect(DarkModeUtil.toThemeMode('light'), ThemeMode.light);
      expect(DarkModeUtil.toThemeMode('dark'), ThemeMode.dark);
      expect(DarkModeUtil.toThemeMode('whatever'), ThemeMode.light);
    });

    testWidgets('shield icon彩蛋', (tester) async {
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
  });

  group('字号与固定尺寸', () {
    test('字号档位 -> 应用内倍率', () {
      expect(FontScaleUtil.toScale('large'), FontScaleUtil.large);
      expect(FontScaleUtil.toScale('normal'), FontScaleUtil.normal);
      expect(FontScaleUtil.toScale('unknown'), FontScaleUtil.normal);
    });

    testWidgets('固定尺寸随文字缩放等比放大, 且封顶 1.6 倍', (tester) async {
      Future<double> scaledAt(double textScale) async {
        late double result;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Builder(
                builder: (context) {
                  result = AccountUiUtils.scaledFixed(context, 68);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        return result;
      }

      expect(await scaledAt(1.0), 68); // 标准档不变
      expect(await scaledAt(1.2), closeTo(81.6, 0.01)); // 大号字体
      expect(await scaledAt(2.0), closeTo(108.8, 0.01)); // 1.6封顶
    });
  });
}
