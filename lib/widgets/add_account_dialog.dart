/*
 * @Author: Thoma4
 * @Date: 2026-08-30 22:24:38
 * @LastEditTime: 2026-10-06 14:02:14
 * @Description: 新建账户表单对话框
 */

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../services/storage_service.dart';
import '../utils/utils.dart';
import 'account_form_fields.dart';
import 'app_dialogs.dart';

// 弹出"新建账户"对话框
Future<bool?> showNewAccountDialog(
  BuildContext context, {
  required Set<String> globalTags,
}) {
  return showDialog<bool>(
    context: context,
    // 两页向导中途点外部关闭会静默丢数据
    barrierDismissible: false,
    builder: (context) => AddAccountDialog(globalTags: globalTags),
  );
}

class AddAccountDialog extends StatefulWidget {
  final Set<String> globalTags; // 标签补全来源

  const AddAccountDialog({super.key, required this.globalTags});

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  // 第1页: 必填
  final _platformController = TextEditingController();
  final _nameController = TextEditingController();
  final _userIdController = TextEditingController();
  final _pswdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  // 第2页: 选填
  final _urlController = TextEditingController();
  final _tagsController = TextEditingController();
  final _birthController = TextEditingController();
  final _signupController = TextEditingController();
  final _notesController = TextEditingController();

  int _step = 0; // 0=必填页, 1=选填页
  int _status = 1; // 默认使用中
  bool _realName = false;
  bool _passwordVisible = false;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    // 标签输入时刷新补全建议
    _tagsController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _platformController.dispose();
    _nameController.dispose();
    _userIdController.dispose();
    _pswdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _urlController.dispose();
    _tagsController.dispose();
    _birthController.dispose();
    _signupController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // 第1页校验: 平台名必填 + 至少一项关键信息 + 平台名查重
  Future<String?> _validateStep1() async {
    final String platform = _platformController.text.trim();
    if (platform.isEmpty) return "请填写平台名称";
    final bool hasAnyCredential =
        _nameController.text.trim().isNotEmpty ||
        _userIdController.text.trim().isNotEmpty ||
        _pswdController.text.trim().isNotEmpty ||
        _emailController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty;
    if (!hasAnyCredential) {
      return "请至少填写一项关键信息：[昵称 | ID | 密码 | 邮箱 | 手机]";
    }
    if (await StorageService().isPlatformNameExists(platform)) {
      return "平台 '$platform' 已存在，请更换名称";
    }
    return null;
  }

  // 下一步(校验不过留在本页)
  Future<void> _next() async {
    final String? error = await _validateStep1();
    if (!mounted) return;
    if (error != null) {
      MessageUtil.show(context, error, isError: true);
      return;
    }
    setState(() => _step = 1);
  }

  // 保存账户
  Future<void> _save() async {
    final String? error = await _validateStep1();
    if (!mounted) return;
    if (error != null) {
      MessageUtil.show(context, error, isError: true);
      setState(() => _step = 0);
      return;
    }
    final newAccount = Account(
      id: const Uuid().v4(),
      platform: _platformController.text,
      url: _urlController.text,
      status: _status,
      name: _nameController.text,
      userId: _userIdController.text,
      email: _emailController.text,
      pswd: _pswdController.text,
      phone: _phoneController.text,
      birth: _parseDate(_birthController.text),
      notes: _notesController.text,
      signupDate: _parseDate(_signupController.text),
      realName: _realName,
      tags: _tags,
      lastModified: DateTime.now().toIso8601String(),
    );
    await StorageService().insertAccount(newAccount);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  DateTime? _parseDate(String text) =>
      text.trim().isEmpty ? null : DateTime.tryParse(text.trim());

  // 是否已填写任何内容
  bool get _hasInput =>
      _platformController.text.trim().isNotEmpty ||
      _nameController.text.trim().isNotEmpty ||
      _userIdController.text.trim().isNotEmpty ||
      _pswdController.text.isNotEmpty ||
      _emailController.text.trim().isNotEmpty ||
      _phoneController.text.trim().isNotEmpty ||
      _urlController.text.trim().isNotEmpty ||
      _birthController.text.trim().isNotEmpty ||
      _signupController.text.trim().isNotEmpty ||
      _notesController.text.trim().isNotEmpty ||
      _tags.isNotEmpty ||
      _realName;

  // 取消(已填内容先确认)
  void _cancel() {
    if (!_hasInput) {
      Navigator.pop(context, false);
      return;
    }
    AppDialogs.showConfirm(
      context,
      title: "放弃新建？",
      message: "已填写的内容不会保存。",
      confirmText: "确认",
      danger: true,
      onConfirm: () {
        if (mounted) Navigator.pop(context, false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_step == 0 ? "新建账户条目 (1/2)" : "新建账户条目 (2/2)"),
      content: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: _step == 0 ? _buildRequiredStep() : _buildOptionalStep(),
          ),
        ),
      ),
      actions: _step == 0
          ? [
              TextButton(onPressed: _cancel, child: const Text("取消")),
              ElevatedButton(onPressed: _next, child: const Text("下一步")),
            ]
          : [
              TextButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text("上一步"),
              ),
              ElevatedButton(onPressed: _save, child: const Text("完成")),
            ],
    );
  }

  // 第1页: 必填项
  Widget _buildRequiredStep() {
    return AccountRequiredFields(
      platform: _platformController,
      name: _nameController,
      userId: _userIdController,
      pswd: _pswdController,
      email: _emailController,
      phone: _phoneController,
      passwordVisible: _passwordVisible,
      onTogglePassword: () =>
          setState(() => _passwordVisible = !_passwordVisible),
    );
  }

  // 第2页: 均为选填
  Widget _buildOptionalStep() {
    return AccountOptionalFields(
      url: _urlController,
      tags: _tagsController,
      birth: _birthController,
      signup: _signupController,
      notes: _notesController,
      tagList: _tags,
      onTagsChanged: (list) => setState(() => _tags = list),
      globalTags: widget.globalTags,
      status: _status,
      onStatusChanged: (v) => setState(() => _status = v),
      realName: _realName,
      onRealNameChanged: (v) => setState(() => _realName = v),
    );
  }
}
