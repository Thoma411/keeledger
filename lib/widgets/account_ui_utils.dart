/*
 * @Author: Thoma4
 * @Date: 2026-06-24 22:13:52
 * @LastEditTime: 2026-08-14 19:35:18
 * @Description: 视觉样式&辅助组件工具类
 */

import 'dart:io';
import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class AccountUiUtils {
  AccountUiUtils._();

  // 判断当前设备是否为触屏设备(移动端: 手机&平板)
  // 此为"真实设备类型"判断, 不受"桌面模式"开关影响, 供交互/操作逻辑使用
  static bool isTouchDevice() {
    final bool isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    if (isDesktop) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  // 判断当前设备是否为平板(触屏设备且最短边 >= 600dp)
  static bool isTablet(BuildContext context) {
    return isTouchDevice() && MediaQuery.of(context).size.shortestSide >= 600;
  }

  // 判断当前UI是否应展示移动端布局(触屏设备中, 平板受"桌面模式"开关影响)
  static bool isMobileLayout(BuildContext context) {
    if (!isTouchDevice()) return false; // 非触屏设备一定不是移动端布局
    if (!isTablet(context)) return true; // 普通手机: 强制显示手机布局
    // 平板: 取决于"桌面模式"开关
    final bool forceDesktop =
        SettingsService().get('force_desktop_mode') == 'true';
    return !forceDesktop;
  }

  // 将数字状态码转换为易读文字
  static String getStatusText(int status) {
    const map = {0: "未注册", 1: "使用中", 2: "已注销", 3: "无法使用"};
    return map[status] ?? "未知";
  }

  // 获取状态对应的颜色
  static Color getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.green.shade400; // 使用中
      case 0:
        return Colors.amber.shade400; // 未注册
      case 2:
        return Colors.grey.shade400; // 已注销
      case 3:
        return Colors.red.shade400; // 无法使用
      default:
        return Colors.blue.shade400;
    }
  }

  // 构建表格中的彩色状态标签
  static Widget buildStatusChip(int status) {
    Color color;
    switch (status) {
      case 1:
        color = Colors.green;
        break;
      case 2:
        color = Colors.grey;
        break;
      case 3:
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        getStatusText(status),
        style: TextStyle(color: color, fontSize: 10),
      ),
    );
  }

  // 构建统一卡片图标的首字母占位符
  static Widget buildPlaceholder(
    String platform,
    Color statusColor,
    double size, // 方块边长
    double fontSize, // 字母大小
    double borderRadius,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Center(
        child: Text(
          platform.isNotEmpty ? platform[0].toUpperCase() : "?",
          style: TextStyle(
            color: statusColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
