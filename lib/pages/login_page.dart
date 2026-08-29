/*
 * @Author: Thoma4
 * @Date: 2026-02-22 19:47:45
 * @LastEditTime: 2026-08-29 21:56:52
 * @Description: 初始登入界面
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pages/shell_page.dart'; // 用于跳转到 MainShell
import '../services/auth_service.dart';
import '../utils/utils.dart';
import '../widgets/app_dialogs.dart';

// 老用户解锁界面
class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true; // 控制密码可见性

  void _unlock() async {
    // 调用验证逻辑
    bool success = await AuthService().verifyPassword(_passwordController.text);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ShellPage()),
      );
    } else {
      MessageUtil.show(context, "密码错误，请重试");
    }
  }

  // 弹出输入恢复密钥(RK)的对话框
  void _showForgotPasswordDialog() {
    final rkController = TextEditingController();
    AppDialogs.showInputForm(
      context,
      title: "重置主密码",
      message: "请输入您事先保存的恢复密钥 (RK)：",
      fields: [
        AppDialogField(
          controller: rkController,
          label: "恢复密钥",
          hint: "一串 Base64 编码的字符",
        ),
      ],
      confirmText: "验证密钥",
      onConfirm: (dialogContext) async {
        final rkInput = rkController.text.trim();
        if (rkInput.isEmpty) return;

        // 用RK验证并解锁DK
        final ok = await AuthService().verifyRecoveryKey(rkInput);
        if (!dialogContext.mounted) return;
        if (!ok) {
          MessageUtil.show(dialogContext, "密钥验证失败，请检查输入是否正确");
          return;
        }
        Navigator.pop(dialogContext); // 关闭RK输入框
        _showResetPasswordDialog(); // 弹出重置密码对话框
      },
    );
  }

  // 成功验证RK后的重置密码对话框
  void _showResetPasswordDialog() {
    final newPwController = TextEditingController();
    final confirmController = TextEditingController();
    AppDialogs.showInputForm(
      context,
      title: "设置新主密码",
      message: "密钥验证成功！请立即设置新的主密码：",
      barrierDismissible: false,
      fields: [
        AppDialogField(
          controller: newPwController,
          label: "新主密码",
          obscure: true,
        ),
        AppDialogField(
          controller: confirmController,
          label: "确认新主密码",
          obscure: true,
        ),
      ],
      confirmText: "生成新的恢复密钥",
      onConfirm: (dialogContext) async {
        if (newPwController.text != confirmController.text ||
            newPwController.text.length < 6) {
          MessageUtil.show(dialogContext, "密码不一致或长度不足6位");
          return;
        }
        try {
          // 重新包装并轮转恢复密钥
          final newRk = await AuthService().resetMasterPassword(
            newPwController.text,
          );
          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext);
          _showNewRKNotice(newRk); // 弹出新RK展示框
        } catch (e) {
          if (dialogContext.mounted) MessageUtil.show(dialogContext, "重置失败：$e");
        }
      },
    );
  }

  // 重置完密码后的新RK展示框
  void _showNewRKNotice(String newRk) {
    AppDialogs.showSecret(
      context,
      title: "请保存新的恢复密钥",
      message: "如果您忘记了主密码，这是找回数据的唯一方法，请务必妥善保存。",
      secret: newRk,
      onCopied: (dialogContext) async {
        await Clipboard.setData(ClipboardData(text: newRk));
        if (!dialogContext.mounted) return;
        Navigator.pop(dialogContext); // 关闭展示框
        // 此时才正式进入主界面
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ShellPage()),
        );
        if (!mounted) return;
        MessageUtil.show(context, "恢复密钥已复制至剪切板，保险箱已就绪");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20), // 顶部留白
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  "身份验证",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  "请输入主密码以解锁数据库",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "主密码",
                    prefixIcon: const Icon(Icons.password),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _unlock,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("解锁"),
                ),
                const SizedBox(height: 5),
                TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: Text(
                    "忘记主密码？",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 20), // 底部留白
              ],
            ),
          ),
        ),
      ),
    );
  }
}
