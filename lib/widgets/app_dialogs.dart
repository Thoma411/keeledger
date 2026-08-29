/*
 * @Author: Thoma4
 * @Date: 2026-08-29 19:04:31
 * @LastEditTime: 2026-08-29 21:24:22
 * @Description: 统一应用对话框(提示/确认/表单输入/密钥展示)
 */

import 'package:flutter/material.dart';

// 表单输入对话框的单个字段配置
class AppDialogField {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  const AppDialogField({
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
  });
}

class AppDialogs {
  // 纯提示框: 标题 + 内容 + 单个"确认"按钮
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("确认"),
          ),
        ],
      ),
    );
  }

  // 确认框: 取消/确认双按钮, 支持危险红色确认按钮与自定义内容
  static Future<void> showConfirm(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content, // 自定义内容(优先于message)
    String confirmText = "确认",
    bool danger = false,
    required VoidCallback onConfirm,
  }) {
    final ButtonStyle? confirmStyle = danger
        ? ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          )
        : null;
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: content ?? Text(message ?? ""),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onConfirm();
            },
            style: confirmStyle,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // 表单输入框: 多字段(每字段自带controller/标签/密码模式), 确认后由调用方处理并自行pop
  static Future<void> showInputForm(
    BuildContext context, {
    required String title,
    String? message,
    Color? messageColor,
    required List<AppDialogField> fields,
    String confirmText = "确定",
    bool barrierDismissible = true,
    required void Function(BuildContext dialogContext) onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null) ...[
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        messageColor ??
                        Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ...fields.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextField(
                    controller: f.controller,
                    obscureText: f.obscure,
                    decoration: InputDecoration(
                      labelText: f.label,
                      hintText: f.hint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () => onConfirm(dialogContext),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // 密钥展示框: 等宽字体可复制密钥 + 复制按钮(可带警示图标与关闭按钮)
  static Future<void> showSecret(
    BuildContext context, {
    required String title,
    required String secret,
    String? message,
    bool showWarningIcon = false,
    bool showCloseButton = false,
    String copyText = "复制恢复密钥",
    bool barrierDismissible = false,
    required Future<void> Function(BuildContext dialogContext) onCopied,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => AlertDialog(
        title: showWarningIcon
            ? Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title)),
                ],
              )
            : Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
            ],
            SelectableText(
              secret,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontFamilyFallback: ['Microsoft YaHei'],
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          if (showCloseButton)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("关闭"),
            ),
          ElevatedButton(
            onPressed: () => onCopied(dialogContext),
            child: Text(copyText),
          ),
        ],
      ),
    );
  }
}
