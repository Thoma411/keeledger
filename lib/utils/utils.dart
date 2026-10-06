/*
 * @Author: Thoma4
 * @Date: 2026-02-22 14:30:59
 * @LastEditTime: 2026-10-06 17:02:02
 * @Description: 工具类
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_text.dart';

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
  static OverlayEntry? _toastEntry; // 当前悬浮提示的Overlay载体

  // 统一的悬浮胶囊提示
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    bool isError = false,
  }) {
    // 对话框内提示插到Overlay顶层
    final OverlayState? overlay = ModalRoute.of(context) is PopupRoute
        ? Overlay.maybeOf(context, rootOverlay: true)
        : null;
    if (overlay != null) {
      _showOnOverlay(overlay, message, duration, isError);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        width: double.infinity,
        padding: EdgeInsets.zero,
        duration: duration,
        content: Center(child: _capsule(message, isError)),
      ),
    );
  }

  // 胶囊外观(常规/错误)
  static Widget _capsule(String message, bool isError) {
    final Color bg = isError
        ? const Color(0xFFB3261E) // 错误: 红色
        : const Color.fromARGB(255, 32, 32, 32); // 常规: 深灰(与主题一致)
    return Container(
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
          fontSize: AppText.body,
          fontFamily: 'Segoe UI',
          fontFamilyFallback: ['Microsoft YaHei'],
        ),
      ),
    );
  }

  // 盖在遮罩之上显示(同一时刻只保留一条)
  static void _showOnOverlay(
    OverlayState overlay,
    String message,
    Duration duration,
    bool isError,
  ) {
    final OverlayEntry? previous = _toastEntry;
    _toastEntry = null;
    if (previous != null && previous.mounted) previous.remove();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _OverlayToast(
        message: message,
        isError: isError,
        duration: duration,
        onDone: () {
          if (identical(_toastEntry, entry)) _toastEntry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _toastEntry = entry;
    overlay.insert(entry);
  }
}

// Overlay版悬浮胶囊
class _OverlayToast extends StatefulWidget {
  final String message;
  final bool isError;
  final Duration duration;
  final VoidCallback onDone;

  const _OverlayToast({
    required this.message,
    required this.isError,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_OverlayToast> createState() => _OverlayToastState();
}

class _OverlayToastState extends State<_OverlayToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _hide);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _hide() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            type: MaterialType.transparency,
            child: FadeTransition(
              opacity: _controller,
              child: Center(
                child: MessageUtil._capsule(widget.message, widget.isError),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
