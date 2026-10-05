/*
 * @Author: Thoma4
 * @Date: 2026-10-05 17:22:39
 * @LastEditTime: 2026-10-05 17:58:31
 * @Description: 新增账户页
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../services/storage_service.dart';
import '../utils/app_text.dart';
import '../utils/utils.dart';
import '../widgets/account_form_fields.dart';
import '../widgets/app_dialogs.dart';

// 进入新增账户页, 返回是否创建成功
Future<bool?> showAccountCreatePage(
  BuildContext context, {
  required Set<String> globalTags,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => AccountCreatePage(globalTags: globalTags),
    ),
  );
}

class AccountCreatePage extends StatefulWidget {
  final Set<String> globalTags; // 标签补全来源

  const AccountCreatePage({super.key, required this.globalTags});

  @override
  State<AccountCreatePage> createState() => _AccountCreatePageState();
}

class _AccountCreatePageState extends State<AccountCreatePage> {
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
  final _signupDateController = TextEditingController();
  final _notesController = TextEditingController();

  int _step = 0; // 0=必填页, 1=选填页
  int _status = 1;
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
    _signupDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // 第1页校验: 平台名必填+至少一项关键信息+平台名查重
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

  // 下一步
  Future<void> _next() async {
    final String? error = await _validateStep1();
    if (!mounted) return;
    // 校验不过留在本页
    if (error != null) {
      MessageUtil.show(context, error, isError: true);
      return;
    }
    setState(() => _step = 1);
  }

  // 创建条目
  Future<void> _save() async {
    final String? error = await _validateStep1();
    if (!mounted) return;
    if (error != null) {
      MessageUtil.show(context, error, isError: true);
      setState(() => _step = 0);
      return;
    }
    final account = Account(
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
      signupDate: _parseDate(_signupDateController.text),
      realName: _realName,
      tags: _tags,
      lastModified: DateTime.now().toIso8601String(),
    );
    await StorageService().insertAccount(account);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  DateTime? _parseDate(String text) =>
      text.trim().isEmpty ? null : DateTime.tryParse(text.trim());

  // 是否已填写内容
  bool get _hasInput =>
      _platformController.text.trim().isNotEmpty ||
      _nameController.text.trim().isNotEmpty ||
      _userIdController.text.trim().isNotEmpty ||
      _pswdController.text.isNotEmpty ||
      _emailController.text.trim().isNotEmpty ||
      _phoneController.text.trim().isNotEmpty ||
      _urlController.text.trim().isNotEmpty ||
      _birthController.text.trim().isNotEmpty ||
      _signupDateController.text.trim().isNotEmpty ||
      _notesController.text.trim().isNotEmpty ||
      _tags.isNotEmpty ||
      _realName;

  // 退出确认
  void _confirmExit() {
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _step == 0 ? "新建账户 (1/2)" : "新建账户 (2/2)",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppText.section,
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
        body: IndexedStack(
          index: _step,
          children: [_buildRequiredStep(), _buildOptionalStep()],
        ),
      ),
    );
  }

  // 第1页: 必填项
  Widget _buildRequiredStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AccountFieldRow(
          label: "平台名称（必填）",
          controller: _platformController,
          isEditing: true,
        ),
        const SizedBox(height: 8),
        _hint("以下至少填写一项"),
        AccountFieldRow(
          label: "用户昵称",
          controller: _nameController,
          isEditing: true,
        ),
        AccountFieldRow(
          label: "登录账号",
          controller: _userIdController,
          isEditing: true,
        ),
        AccountPasswordRow(
          controller: _pswdController,
          isEditing: true,
          isVisible: _passwordVisible,
          onToggleVisible: () =>
              setState(() => _passwordVisible = !_passwordVisible),
        ),
        AccountFieldRow(
          label: "绑定邮箱",
          controller: _emailController,
          isEditing: true,
        ),
        AccountFieldRow(
          label: "绑定手机",
          controller: _phoneController,
          isEditing: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
      ],
    );
  }

  // 第2页: 均为选填
  Widget _buildOptionalStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hint("以下均为选填，可直接完成"),
        AccountFieldRow(
          label: "网址",
          controller: _urlController,
          isEditing: true,
        ),
        AccountTagsRow(
          tags: _tags,
          controller: _tagsController,
          isEditing: true,
          globalTags: widget.globalTags,
          onChanged: (list) => setState(() => _tags = list),
        ),
        _buildStatusRow(),
        AccountFieldRow(
          label: "生日",
          controller: _birthController,
          isEditing: true,
          isDateField: true,
        ),
        AccountFieldRow(
          label: "注册日期",
          controller: _signupDateController,
          isEditing: true,
          isDateField: true,
        ),
        CheckboxListTile(
          title: const Text("是否已实名", style: TextStyle(fontSize: AppText.body)),
          value: _realName,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() => _realName = v ?? false),
        ),
        AccountFieldRow(
          label: "备注",
          controller: _notesController,
          isEditing: true,
          maxLines: 5,
        ),
      ],
    );
  }

  // 账户状态下拉
  Widget _buildStatusRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<int>(
        initialValue: _status,
        decoration: InputDecoration(
          labelText: "账户状态",
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: AppText.caption,
          ),
        ),
        items: const [
          DropdownMenuItem(value: 1, child: Text("使用中")),
          DropdownMenuItem(value: 0, child: Text("未注册")),
          DropdownMenuItem(value: 2, child: Text("已注销")),
          DropdownMenuItem(value: 3, child: Text("无法使用")),
        ],
        onChanged: (v) => setState(() => _status = v ?? 1),
      ),
    );
  }

  // 说明文字
  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppText.caption,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  // 底部操作栏
  Widget _buildBottomBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.6),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _step == 0
            ? [
                TextButton.icon(
                  onPressed: _confirmExit,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text("取消"),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("下一步"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                ),
              ]
            : [
                TextButton.icon(
                  onPressed: () => setState(() => _step = 0),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("上一步"),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text("完成"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
      ),
    );
  }
}
