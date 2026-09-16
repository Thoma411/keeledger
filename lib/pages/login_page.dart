/*
 * @Author: Thoma4
 * @Date: 2026-02-22 19:47:45
 * @LastEditTime: 2026-09-16 22:51:05
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
  final FocusNode _passwordFocus = FocusNode(); // 指纹失败/取消后把焦点交还密码框
  final AuthService _auth = AuthService();
  bool _obscurePassword = true; // 控制密码可见性
  bool _bioEnabled = false; // 本机已开启指纹解锁
  bool _bioAvailable = false; // 设备指纹当前可用
  bool _bioBusy = false; // 防止重复触发认证
  bool _autoPrompted = false; // 本次进入解锁页只自动弹一次
  int _bioLockRemaining = 0; // 系统锁定剩余秒数(>0 表示暂不可用)
  bool _bioLockCounting = false; // 倒计时进行中

  @override
  void initState() {
    super.initState();
    _bioEnabled = _auth.isBiometricEnabled();
    if (_bioEnabled) _initBiometric();
  }

  @override
  void dispose() {
    _passwordFocus.dispose();
    super.dispose();
  }

  // 检测指纹可用性, 并在本次进入解锁页时自动弹一次系统指纹提示
  Future<void> _initBiometric() async {
    final bool usable = await _auth.isBiometricUsable();
    if (!mounted) return;
    setState(() => _bioAvailable = usable);
    if (!usable || _autoPrompted) return;
    _autoPrompted = true;
    // 等首帧之后再弹, 否则系统提示可能不显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unlockWithBiometric();
    });
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ShellPage()),
    );
  }

  void _unlock() async {
    // 调用验证逻辑
    bool success = await _auth.verifyPassword(_passwordController.text);
    if (!mounted) return;
    if (success) {
      _goHome();
    } else {
      MessageUtil.show(context, "密码错误，请重试");
    }
  }

  // 指纹解锁
  Future<void> _unlockWithBiometric() async {
    if (_bioBusy) return;
    // 系统锁定期间不触发认证(状态由按钮上的倒计时呈现, 不再弹提示)
    if (_bioLockRemaining > 0) return;
    setState(() => _bioBusy = true);
    final BiometricUnlockResult result = await _auth.unlockWithBiometric();
    if (!mounted) return;
    setState(() => _bioBusy = false);
    switch (result) {
      case BiometricUnlockResult.success:
        _goHome();
        break;
      case BiometricUnlockResult.canceled:
        // 用户主动取消: 不报错, 静默交还给密码输入
        _passwordFocus.requestFocus();
        break;
      case BiometricUnlockResult.lockedOut:
        // 尝试次数过多被系统短暂锁定: 交由按钮显示倒计时
        _startLockCountdown();
        _passwordFocus.requestFocus();
        break;
      case BiometricUnlockResult.notEnabled:
      case BiometricUnlockResult.invalidated:
        setState(() {
          _bioEnabled = false;
          _bioAvailable = false;
        });
        MessageUtil.show(context, "指纹解锁已失效，请用主密码解锁后重新开启");
        _passwordFocus.requestFocus();
        break;
      case BiometricUnlockResult.failed:
        MessageUtil.show(context, "指纹解锁失败，请重试或使用主密码", isError: true);
        _passwordFocus.requestFocus();
        break;
    }
  }

  // 系统锁定(约 30 秒): 只把倒计时显示在解锁按钮上, 不再弹悬浮提示
  void _startLockCountdown() {
    setState(() => _bioLockRemaining = 30);
    if (_bioLockCounting) return; // 已在倒计时
    _bioLockCounting = true;
    _runLockCountdown();
  }

  Future<void> _runLockCountdown() async {
    while (_bioLockRemaining > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _bioLockRemaining--);
    }
    _bioLockCounting = false;
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
                  _bioEnabled && _bioAvailable
                      ? "请按压指纹解锁，或输入主密码"
                      : (_bioEnabled ? "指纹暂不可用，请输入主密码" : "请输入主密码以解锁数据库"),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
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
                if (_bioEnabled && _bioAvailable) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    // 系统锁定期间保持可点, 点击后提示剩余秒数
                    onPressed: _bioBusy ? null : _unlockWithBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(
                      _bioLockRemaining > 0
                          ? "指纹已锁定（$_bioLockRemaining 秒）"
                          : "使用指纹解锁",
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                    ),
                  ),
                ],
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
