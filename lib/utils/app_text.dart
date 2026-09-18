/*
 * @Author: Thoma4
 * @Date: 2026-09-18 01:07:59
 * @LastEditTime: 2026-09-18 22:07:40
 * @Description: 应用字号标准
 */

import 'package:flutter/material.dart';

// 字号标准: 全应用文字的唯一真源
class AppText {
  AppText._();

  // 标准字号
  static const double display = 22; // 页面级大标题
  static const double section = 18; // 分区标题
  static const double title = 15; // 列表项/卡片主标题
  static const double body = 14; // 正文
  static const double sub = 13; // 次要正文
  static const double caption = 12; // 说明/时间/日志
  static const double label = 11; // 标签/辅助

  // 固定尺寸(不缩放)
  static const double indexLetter = 10; // 字母索引条
  static const double bubble = 34; // 索引气泡

  static TextTheme buildTextTheme(ColorScheme cs) {
    return TextTheme(
      // 页面级标题(对话框标题也走 headlineSmall)
      headlineSmall: TextStyle(
        fontSize: display,
        fontWeight: FontWeight.bold,
        color: cs.onSurface,
      ),
      // 分区标题/AppBar标题
      titleLarge: TextStyle(
        fontSize: section,
        fontWeight: FontWeight.bold,
        color: cs.onSurface,
      ),
      titleMedium: TextStyle(fontSize: title, color: cs.onSurface),
      // 正文
      bodyLarge: TextStyle(fontSize: title, color: cs.onSurface),
      bodyMedium: TextStyle(
        fontSize: body,
        letterSpacing: 0.2,
        color: cs.onSurface,
      ),
      bodySmall: TextStyle(fontSize: caption, color: cs.onSurfaceVariant),
      // 按钮/标签
      labelLarge: TextStyle(fontSize: body, color: cs.onSurface),
      labelMedium: TextStyle(
        fontSize: caption,
        letterSpacing: 0.2,
        color: cs.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontSize: label,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}
