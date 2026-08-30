/*
 * @Author: Thoma4
 * @Date: 2026-08-30 22:24:38
 * @LastEditTime: 2026-08-30 22:29:17
 * @Description: 新增账户表单对话框
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../services/storage_service.dart';
import 'app_dialogs.dart';

// 弹出"新增账户"表单对话框
Future<bool?> showNewAccountDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const AddAccountDialog(),
  );
}

class AddAccountDialog extends StatefulWidget {
  const AddAccountDialog({super.key});

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  final _formKey = GlobalKey<FormState>();

  // 表单输入值
  String platform = '',
      url = '',
      name = '',
      userId = '',
      email = '',
      pswd = '',
      phone = '',
      notes = '',
      tagsStr = '';
  int status = 1; // 默认使用中
  bool realName = false;

  final _birthController = TextEditingController();
  final _signupController = TextEditingController();

  bool _isExpanded = false; // 默认折叠
  static const double _gap = 6; // 字段间距

  @override
  void dispose() {
    _birthController.dispose();
    _signupController.dispose();
    super.dispose();
  }

  // 日期选择器
  Future<void> _pickDate(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(date);
    }
  }

  // 保存账户
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // 平台重名检测
    final storage = StorageService();
    bool isDuplicate = await storage.isPlatformNameExists(platform);
    if (isDuplicate) {
      if (!mounted) return;
      AppDialogs.showInfo(
        context,
        title: "平台名冲突",
        message: "平台 '$platform' 已存在，请更换名称。",
      );
      return;
    }
    // 检测是否充分填写信息
    bool hasAnyCredential =
        name.trim().isNotEmpty ||
        userId.trim().isNotEmpty ||
        pswd.trim().isNotEmpty ||
        email.trim().isNotEmpty ||
        phone.trim().isNotEmpty;
    if (!hasAnyCredential) {
      if (!mounted) return;
      AppDialogs.showInfo(
        context,
        title: "信息不足",
        message: "请至少填写一项关键信息：[昵称 | ID | 密码 | 邮箱 | 手机]",
      );
      return;
    }
    // 保存新账户
    final newAccount = Account(
      id: const Uuid().v4(),
      platform: platform,
      url: url,
      status: status,
      name: name,
      userId: userId,
      email: email,
      pswd: pswd,
      phone: phone,
      birth: _birthController.text.trim().isEmpty
          ? null
          : DateTime.tryParse(_birthController.text),
      notes: notes,
      signupDate: _signupController.text.trim().isEmpty
          ? null
          : DateTime.tryParse(_signupController.text),
      realName: realName,
      tags: tagsStr
          .split(RegExp(r'[,，]'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .take(8)
          .toList(), // 标签最大数量: 8
      lastModified: DateTime.now().toIso8601String(),
    );
    await StorageService().insertAccount(newAccount);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("新增账户条目"),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, // 紧凑布局
              children: [
                // 关键信息
                SizedBox(height: _gap / 2),
                TextFormField(
                  decoration: const InputDecoration(labelText: "平台名称*"),
                  validator: (v) => (v == null || v.isEmpty) ? "请输入平台名称" : null,
                  onChanged: (v) => platform = v,
                ),
                const Divider(),
                TextFormField(
                  decoration: const InputDecoration(labelText: "用户昵称*"),
                  onChanged: (v) => name = v,
                ),
                SizedBox(height: _gap),
                TextFormField(
                  decoration: const InputDecoration(labelText: "用户ID*"),
                  onChanged: (v) => userId = v,
                ),
                SizedBox(height: _gap),
                TextFormField(
                  decoration: const InputDecoration(labelText: "密码*"),
                  onChanged: (v) => pswd = v,
                ),
                SizedBox(height: _gap),
                TextFormField(
                  decoration: const InputDecoration(labelText: "绑定邮箱*"),
                  onChanged: (v) => email = v,
                ),
                SizedBox(height: _gap),
                TextFormField(
                  decoration: const InputDecoration(labelText: "绑定手机*"),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  onChanged: (v) => phone = v,
                ),
                SizedBox(height: _gap),
                // 附加信息
                AnimatedSize(
                  duration: const Duration(milliseconds: 300), // 动画时长
                  curve: Curves.easeInOut,
                  child: SizedBox(
                    width: double.infinity,
                    child: _isExpanded
                        ? Column(
                            children: [
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: "网址",
                                ),
                                onChanged: (v) => url = v,
                              ),
                              SizedBox(height: _gap),
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: "标签 (逗号分隔)",
                                ),
                                onChanged: (v) => tagsStr = v,
                              ),
                              SizedBox(height: _gap),
                              DropdownButtonFormField<int>(
                                initialValue: status,
                                decoration: const InputDecoration(
                                  labelText: "账户状态",
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 1,
                                    child: Text("使用中"),
                                  ),
                                  DropdownMenuItem(
                                    value: 0,
                                    child: Text("未注册"),
                                  ),
                                  DropdownMenuItem(
                                    value: 2,
                                    child: Text("已注销"),
                                  ),
                                  DropdownMenuItem(
                                    value: 3,
                                    child: Text("无法使用"),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => status = v ?? 1),
                              ),
                              SizedBox(height: _gap),
                              TextFormField(
                                controller: _birthController,
                                decoration: InputDecoration(
                                  labelText: "生日",
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                    ),
                                    onPressed: () =>
                                        _pickDate(_birthController),
                                  ),
                                ),
                              ),
                              SizedBox(height: _gap),
                              TextFormField(
                                controller: _signupController,
                                decoration: InputDecoration(
                                  labelText: "注册日期",
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                    ),
                                    onPressed: () =>
                                        _pickDate(_signupController),
                                  ),
                                ),
                              ),
                              SizedBox(height: _gap),
                              CheckboxListTile(
                                title: const Text("是否已实名"),
                                value: realName,
                                onChanged: (v) {
                                  setState(() {
                                    realName = v ?? false;
                                  });
                                },
                              ),
                              SizedBox(height: _gap),
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: "备注",
                                ),
                                onChanged: (v) => notes = v,
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _isExpanded = !_isExpanded);
                    },
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(_isExpanded ? "收起附加信息" : "填写更多信息"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("取消"),
        ),
        ElevatedButton(onPressed: _save, child: const Text("保存")),
      ],
    );
  }
}
