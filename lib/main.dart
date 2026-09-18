/*
 * @Author: Thoma4
 * @Date: 2026-02-09 23:51:46
 * @LastEditTime: 2026-09-18 13:46:18
 * @Description: main
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'pages/login_page.dart';
import 'pages/shell_page.dart';
import 'services/storage_service.dart';
import 'services/settings_service.dart';
import 'utils/app_text.dart';
import 'utils/utils.dart';

// 深色模式变量
final ValueNotifier<ThemeMode> darkModeNotifier = ValueNotifier(
  ThemeMode.light,
);

// 字号档位变量
final ValueNotifier<double> fontScaleNotifier = ValueNotifier(
  FontScaleUtil.normal,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 确保Flutter引擎绑定
  // 沉浸式状态栏
  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }
  // 电脑端初始化
  if (Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit(); // 初始化SQLite FFI引擎
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized(); // 初始化窗口管理器
    WindowOptions windowOptions = const WindowOptions(
      size: Size(800, 600),
      minimumSize: Size(800, 600),
      center: true,
      title: "Keeledger",
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  await SettingsService().init(); // 加载本地配置

  // 探测本地数据库是否存在
  final bool oldUser = await StorageService().isDatabaseExists();

  // 从配置中读取初始主题状态
  darkModeNotifier.value = DarkModeUtil.toThemeMode(
    SettingsService().darkModeValue,
  );
  // 从配置中读取初始字号档位
  fontScaleNotifier.value = FontScaleUtil.toScale(
    SettingsService().fontScaleValue,
  );

  runApp(KeeledgerApp(isOldUser: oldUser)); // 运行应用并传递状态
}

class KeeledgerApp extends StatelessWidget {
  final bool isOldUser;
  const KeeledgerApp({super.key, required this.isOldUser});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: darkModeNotifier,
      builder: (_, mode, _) {
        return ValueListenableBuilder<double>(
          valueListenable: fontScaleNotifier,
          builder: (_, fontScale, _) {
            return MaterialApp(
              title: "Keeledger",
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: _buildLightTheme(), // 浅色主题
              darkTheme: _buildDarkTheme(), // 深色主题
              // 在渲染层统一缩放字号档位
              builder: (context, child) =>
                  _applyFontScale(context, child, fontScale),
              // 根据是否为老用户进入不同的界面
              home: isOldUser ? const UnlockPage() : const ShellPage(),
            );
          },
        );
      },
    );
  }

  // 叠乘系统字体缩放
  Widget _applyFontScale(BuildContext context, Widget? child, double appScale) {
    if (child == null) return const SizedBox.shrink();
    if (appScale == FontScaleUtil.normal) return child;
    final MediaQueryData mq = MediaQuery.of(context);
    final double system = mq.textScaler.scale(1.0);
    final double scale = (system * appScale).clamp(
      FontScaleUtil.minScale,
      FontScaleUtil.maxScale,
    );
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    );
  }

  ThemeData _buildLightTheme() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ).copyWith(
          primary: Colors.blue, // 主题色
          onSurfaceVariant: const Color.fromARGB(255, 81, 84, 90), // 副文字
          outlineVariant: const Color(0xFFC4C6D0), // 边框
          error: Colors.red,
        );
    return _buildBaseTheme(colorScheme);
  }

  ThemeData _buildDarkTheme() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF82B1FF), // 主题色
          onSurfaceVariant: const Color(0xFF8E9199), // 副文字
          // surfaceContainer: Color.fromARGB(255, 47, 47, 49),
        );
    return _buildBaseTheme(colorScheme);
  }

  ThemeData _buildBaseTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Segoe UI', //设置主字体
      // 遇到中文字符时按顺序寻找以下字体
      fontFamilyFallback: const [
        'Microsoft YaHei', // Windows 默认中文
        'PingFang SC', // iOS/macOS 默认中文
        'Hiragino Sans GB',
        'sans-serif',
      ],
      // 增强文本渲染清晰度(针对Windows)
      typography: Typography.material2021(platform: TargetPlatform.windows),
      // 字号标准
      textTheme: AppText.buildTextTheme(colorScheme),

      // 卡片配置
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // 统一输入框风格
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}
