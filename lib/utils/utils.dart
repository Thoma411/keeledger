/*
 * @Author: Thoma4
 * @Date: 2026-02-22 14:30:59
 * @LastEditTime: 2026-09-18 14:11:44
 * @Description: 工具类
 */

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateUtil {
  // 将 ISO8601 字符串转换为 yyyy-MM-dd HH:mm 格式
  static String format(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "无记录";
    try {
      DateTime dt = DateTime.parse(isoString).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (e) {
      return isoString;
    }
  }
}

class DarkModeUtil {
  // 深色模式设置值
  static ThemeMode toThemeMode(String darkMode) {
    switch (darkMode) {
      case 'system':
        return ThemeMode.system;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.light;
    }
  }
}

class FontScaleUtil {
  // 字号档位: 设置值->应用内倍率(参与系统字号设置叠乘)
  static const double normal = 1.0; // 标准
  static const double large = 1.2; // 大号字体
  // 最终倍率的上下限
  static const double minScale = 0.85;
  static const double maxScale = 2.0;
  // 设置值('normal'/'large')->应用内倍率
  static double toScale(String level) => level == 'large' ? large : normal;
  // 是否为大号字体
  static bool isLarge(String level) => level == 'large';
}

class MessageUtil {
  // 统一的悬浮胶囊提示: 圆角、自动根据文字调整宽度、居中显示
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    bool isError = false,
  }) {
    final Color bg = isError
        ? const Color(0xFFB3261E) // 错误: 红色
        : const Color.fromARGB(255, 32, 32, 32); // 常规: 深灰(与主题一致)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        width: double.infinity,
        padding: EdgeInsets.zero,
        duration: duration,
        content: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Segoe UI',
                fontFamilyFallback: ['Microsoft YaHei'],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
