/*
 * @Author: Thoma4
 * @Date: 2026-06-24 23:04:48
 * @LastEditTime: 2026-10-04 21:08:51
 * @Description: 账户信息详情页
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../services/icon_store.dart';
import '../services/storage_service.dart';
import '../utils/app_text.dart';
import '../utils/utils.dart';
import 'account_form_fields.dart';
import 'account_ui_utils.dart';
import 'app_dialogs.dart';

class AccountDetailView extends StatefulWidget {
  final Account account;
  final Set<String> globalTags;
  final VoidCallback onClose;
  final VoidCallback onSaveSuccess; // 数据保存成功回调
  final VoidCallback onDeleteSuccess; // 数据删除成功回调
  final ValueChanged<String>? onTagClicked;

  const AccountDetailView({
    super.key,
    required this.account,
    required this.globalTags,
    required this.onClose,
    required this.onSaveSuccess,
    required this.onDeleteSuccess,
    required this.onTagClicked,
  });

  @override
  State<AccountDetailView> createState() => _AccountDetailViewState();
}

class _AccountDetailViewState extends State<AccountDetailView> {
  final _formKey = GlobalKey<FormState>();
  // 详情页字段控制器
  late TextEditingController _platformController,
      _nameController,
      _urlController,
      _userIdController,
      _emailController,
      _pswdController,
      _phoneController,
      _birthController,
      _notesController,
      _signupDateController,
      _tagsController;
  bool _isEditing = false; // 是否正在编辑

  int _currentStatus = 1;
  bool _currentRealName = false;
  bool _favorite = false;
  bool _isPasswordVisible = false;

  List<String> _tempTags = []; // 临时标签集

  @override
  void initState() {
    super.initState();
    // 物理实例化
    _platformController = TextEditingController();
    _nameController = TextEditingController();
    _urlController = TextEditingController();
    _userIdController = TextEditingController();
    _emailController = TextEditingController();
    _pswdController = TextEditingController();
    _phoneController = TextEditingController();
    _birthController = TextEditingController();
    _notesController = TextEditingController();
    _signupDateController = TextEditingController();
    _tagsController = TextEditingController();
    // 监听标签输入
    _tagsController.addListener(() {
      if (_isEditing) setState(() {});
    });
    _initFields(widget.account);
  }

  // 释放资源防止内存泄露
  @override
  void dispose() {
    _platformController.dispose();
    _nameController.dispose();
    _urlController.dispose();
    _userIdController.dispose();
    _emailController.dispose();
    _pswdController.dispose();
    _phoneController.dispose();
    _birthController.dispose();
    _notesController.dispose();
    _signupDateController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  // 电脑端切换卡片时重新刷入新账号数据
  @override
  void didUpdateWidget(covariant AccountDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果切换了不同的账户条目，重新刷入新表单控制器数据
    if (oldWidget.account.id != widget.account.id) {
      _initFields(widget.account);
    }
  }

  // 初始化控制器&变量
  void _initFields(Account acc) {
    _isEditing = false; // 切换或重载时重置为只读
    _platformController.text = acc.platform;
    _nameController.text = acc.name;
    _urlController.text = acc.url;
    _userIdController.text = acc.userId;
    _emailController.text = acc.email;
    _pswdController.text = acc.pswd;
    _phoneController.text = acc.phone;
    _birthController.text = acc.birth != null
        ? DateFormat('yyyy-MM-dd').format(acc.birth!)
        : "";
    _notesController.text = acc.notes ?? "";
    _signupDateController.text = acc.signupDate != null
        ? DateFormat('yyyy-MM-dd').format(acc.signupDate!)
        : "";
    _currentStatus = acc.status;
    _currentRealName = acc.realName;
    _favorite = acc.favorite;
    _tempTags = List.from(acc.tags);
  }

  // 构建详情面板的顶部区域
  Widget _buildDetailHeader(Account account) {
    final Color statusColor = AccountUiUtils.getStatusColor(_currentStatus);
    return Container(
      padding: const EdgeInsets.all(24),
      // 背景采用极淡的状态色，增强氛围感
      color: statusColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          _buildLargeLogo(account), // 左侧大图标
          const SizedBox(width: 20),
          // 中间标题与状态标签
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEditing) ...[
                  // 只读态与编辑态共用输入框装饰, 保证两态头部高度一致
                  _readOnlyValue(
                    account.platform,
                    style: const TextStyle(
                      fontSize: AppText.display,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  // 与编辑态下拉框同高
                  SizedBox(
                    height: AccountUiUtils.scaledFixed(context, 35),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AccountUiUtils.buildStatusChip(_currentStatus),
                    ),
                  ),
                ] else ...[
                  // 编辑模式：标题变输入框
                  TextFormField(
                    controller: _platformController,
                    style: const TextStyle(
                      fontSize: AppText.display,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: accountFieldDecoration(context, hint: "平台名称"),
                  ),
                  const SizedBox(height: 4),
                  // 状态变下拉框
                  SizedBox(
                    height: AccountUiUtils.scaledFixed(context, 35),
                    child: DropdownButton<int>(
                      value: _currentStatus,
                      isDense: true,
                      underline: const SizedBox(), // 隐藏下划线
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            "使用中",
                            style: TextStyle(fontSize: AppText.caption),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 0,
                          child: Text(
                            "未注册",
                            style: TextStyle(fontSize: AppText.caption),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(
                            "已注销",
                            style: TextStyle(fontSize: AppText.caption),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(
                            "无法使用",
                            style: TextStyle(fontSize: AppText.caption),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _currentStatus = v ?? 1),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 星标切换按钮
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              _favorite ? Icons.bookmark : Icons.bookmark_border,
              color: _favorite
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            tooltip: _favorite ? "取消星标" : "加入星标",
          ),
          // 右侧关闭按钮
          IconButton(
            onPressed: widget.onClose, // 调用State类中的关闭方法
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            tooltip: "关闭面板",
          ),
        ],
      ),
    );
  }

  // 构建详情面板顶部的平台大图标/占位符
  Widget _buildLargeLogo(Account account) {
    final Color color = AccountUiUtils.getStatusColor(account.status);
    final icon = IconStore().iconFor(account);
    if (icon != null) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.memory(
            icon,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                AccountUiUtils.buildPlaceholder(
                  account.platform,
                  color,
                  64,
                  28,
                  16,
                ),
          ),
        ),
      );
    }
    // 未抓取/未指定时显示首字母占位符
    return AccountUiUtils.buildPlaceholder(account.platform, color, 64, 28, 16);
  }

  // 构建详情页内小图标
  Widget _buildSmallLogo(Account acc, Color color) {
    final icon = IconStore().iconFor(acc);
    if (icon != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          icon,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              AccountUiUtils.buildPlaceholder(acc.platform, color, 40, 18, 8),
        ),
      );
    }
    return AccountUiUtils.buildPlaceholder(acc.platform, color, 40, 18, 8);
  }

  // 构建信息展示行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: AppText.caption,
            ),
          ),
          const SizedBox(height: 4),
          _readOnlyValue(
            value,
            style: const TextStyle(
              fontSize: AppText.body,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // 只读态值渲染: 与输入框共用装饰
  Widget _readOnlyValue(String text, {TextStyle? style, int? maxLines}) =>
      readOnlyFieldValue(context, text, style: style, maxLines: maxLines);

  // 构建可编辑信息展示行
  Widget _buildEditableInfoRow(
    String label,
    TextEditingController controller, {
    bool isDateField = false,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return AccountFieldRow(
      label: label,
      controller: controller,
      isEditing: _isEditing,
      isDateField: isDateField,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
    );
  }

  // 构建带跳转功能的展示行
  Widget _buildInfoRowWithLink(String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: AppText.caption,
            ),
          ),
          InkWell(
            onTap: url.isEmpty ? null : () => launchUrl(Uri.parse(url)),
            child: _readOnlyValue(
              url.isEmpty ? "-" : url,
              style: TextStyle(
                fontSize: AppText.body,
                color: url.isEmpty
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.primary,
                decoration: url.isEmpty ? null : TextDecoration.underline,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // 构建可编辑url展示行
  Widget _buildEditableUrlRow() {
    return _isEditing
        ? _buildEditableInfoRow("网址", _urlController)
        : _buildInfoRowWithLink("网址", _urlController.text);
  }

  // 构建实名标记行
  Widget _buildEditableRealNameRow() {
    if (!_isEditing) {
      return _buildInfoRow("实名标记", _currentRealName ? "已实名" : "未实名");
    }
    return CheckboxListTile(
      title: const Text("实名标记", style: TextStyle(fontSize: AppText.body)),
      value: _currentRealName,
      contentPadding: EdgeInsets.zero,
      onChanged: (v) => setState(() => _currentRealName = v ?? false),
    );
  }

  // 构建可编辑标签行
  Widget _buildEditableTagsRow() {
    return AccountTagsRow(
      tags: _tempTags,
      controller: _tagsController,
      isEditing: _isEditing,
      globalTags: widget.globalTags,
      onChanged: (list) => setState(() => _tempTags = list),
      onTagClicked: widget.onTagClicked,
    );
  }

  // 添加新标签并查重
  void _addNewTag(String val) {
    final List<String>? next = appendTag(context, _tempTags, val);
    if (next == null) return;
    setState(() {
      _tempTags = next;
      _tagsController.clear();
    });
  }

  // 切换状态(只读/编辑)
  void _toggleEditMode() async {
    if (_isEditing) {
      // 去除首尾空格
      _platformController.text = _platformController.text.trim();
      _nameController.text = _nameController.text.trim();
      _urlController.text = _urlController.text.trim();
      _userIdController.text = _userIdController.text.trim();
      _emailController.text = _emailController.text.trim();
      _phoneController.text = _phoneController.text.trim();
      // 自动保存标签输入框中未回车的内容
      if (_tagsController.text.trim().isNotEmpty) {
        _addNewTag(_tagsController.text);
      }
      // 执行保存逻辑
      if (_formKey.currentState!.validate()) {
        // 获取编辑对象
        final acc = widget.account;
        final newName = _platformController.text.trim();
        // 重名检查
        if (newName.toLowerCase() != acc.platform.toLowerCase()) {
          bool exists = await StorageService().isPlatformNameExists(newName);
          if (exists) {
            if (!mounted) return;
            AppDialogs.showInfo(
              context,
              title: "平台名冲突",
              message: "修改失败：平台 '$newName' 已存在，请更换名称。",
            );
            return;
          }
        }
        // 信息充分性检查
        bool hasAnyCredential =
            _nameController.text.trim().isNotEmpty ||
            _userIdController.text.trim().isNotEmpty ||
            _pswdController.text.trim().isNotEmpty ||
            _emailController.text.trim().isNotEmpty ||
            _phoneController.text.trim().isNotEmpty;
        if (!hasAnyCredential) {
          if (!mounted) return;
          AppDialogs.showInfo(
            context,
            title: "保存失败",
            message: "请至少填写一项关键信息：[ 昵称 | ID | 密码 | 邮箱 | 手机 ]",
          );
          return;
        }
        // 脏检查
        bool hasChanged =
            _platformController.text != acc.platform ||
            _nameController.text != acc.name ||
            _urlController.text != acc.url ||
            _userIdController.text != acc.userId ||
            _emailController.text != acc.email ||
            _pswdController.text != acc.pswd ||
            _phoneController.text != acc.phone ||
            _birthController.text !=
                (acc.birth == null
                    ? ""
                    : DateFormat('yyyy-MM-dd').format(acc.birth!)) ||
            _notesController.text != (acc.notes ?? "") ||
            _signupDateController.text !=
                (acc.signupDate == null
                    ? ""
                    : DateFormat('yyyy-MM-dd').format(acc.signupDate!)) ||
            _currentStatus != acc.status ||
            _currentRealName != acc.realName ||
            !listEquals(_tempTags, acc.tags);
        if (!hasChanged) {
          setState(() => _isEditing = false);
          debugPrint("account changed flag: $hasChanged");
          return;
        }
        // 有变动 执行更新
        final updated = Account(
          id: acc.id, // 保持ID
          platform: _platformController.text,
          name: _nameController.text,
          url: _urlController.text,
          status: _currentStatus,
          userId: _userIdController.text,
          email: _emailController.text,
          pswd: _pswdController.text,
          phone: _phoneController.text,
          birth: _birthController.text.isEmpty
              ? null
              : DateTime.tryParse(_birthController.text),
          notes: _notesController.text,
          signupDate: _signupDateController.text.isEmpty
              ? null
              : DateTime.tryParse(_signupDateController.text),
          realName: _currentRealName,
          favorite: _favorite,
          tags: _tempTags,
          lastModified: DateTime.now().toIso8601String(),
        );
        await StorageService().insertAccount(updated);
        if (!mounted) return;
        widget.onSaveSuccess(); // 通知大列表重载数据
        MessageUtil.show(context, "修改已保存");
        setState(() => _isEditing = false);
      }
    } else {
      setState(() => _isEditing = true); // 切换到编辑状态
    }
  }

  // 切换书签星标状态
  Future<void> _toggleFavorite() async {
    final acc = widget.account;
    final target = !_favorite;
    setState(() => _favorite = target); // 先即时反馈UI
    final updated = Account(
      id: acc.id,
      platform: acc.platform,
      name: acc.name,
      url: acc.url,
      status: acc.status,
      userId: acc.userId,
      email: acc.email,
      pswd: acc.pswd,
      phone: acc.phone,
      birth: acc.birth,
      notes: acc.notes,
      signupDate: acc.signupDate,
      realName: acc.realName,
      favorite: target,
      tags: acc.tags,
      lastModified: acc.lastModified,
    );
    try {
      await StorageService().insertAccount(updated);
      if (!mounted) return;
      widget.onSaveSuccess(); // 通知列表刷新(并推进同步修订号)
      MessageUtil.show(context, target ? "已加入星标" : "已取消星标");
    } catch (e) {
      if (!mounted) return;
      setState(() => _favorite = !target); // 失败回滚
      MessageUtil.show(context, "书签操作失败: $e", isError: true);
    }
  }

  // 构建底部常驻操作栏
  Widget _buildBottomActionBar() {
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
        children: _isEditing
            ? [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _initFields(widget.account); // 取消编辑: 回滚并重新填充
                    });
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text("取消"),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleEditMode, // 保存编辑: 触发验证与写入
                  icon: const Icon(Icons.save_as_outlined),
                  label: const Text("保存修改"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                ),
              ]
            : [
                TextButton.icon(
                  onPressed: _toggleEditMode, // 点击切换编辑状态
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text("编辑账户"),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(widget.account), // 点击弹出删除
                  icon: const Icon(Icons.delete_outline),
                  label: const Text("删除条目"),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                ),
              ],
      ),
    );
  }

  // 构建仅编辑模式下呈现大列表顶端的编辑工作区
  Widget _buildMobileEditingHeaderCard() {
    final Color color = AccountUiUtils.getStatusColor(_currentStatus);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          _buildSmallLogo(widget.account, color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _platformController,
                  style: const TextStyle(
                    fontSize: AppText.section,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: "平台名称",
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 6),
                // 状态修改下拉菜单
                SizedBox(
                  height: AccountUiUtils.scaledFixed(context, 30),
                  child: DropdownButton<int>(
                    value: _currentStatus,
                    isDense: true,
                    underline: const SizedBox(),
                    style: TextStyle(
                      fontSize: AppText.sub,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("使用中")),
                      DropdownMenuItem(value: 0, child: Text("未注册")),
                      DropdownMenuItem(value: 2, child: Text("已注销")),
                      DropdownMenuItem(value: 3, child: Text("无法使用")),
                    ],
                    onChanged: (v) => setState(() => _currentStatus = v ?? 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 弹出删除确认对话框
  void _confirmDelete(Account account) {
    AppDialogs.showConfirm(
      context,
      title: "确认删除",
      message: "确定要删除 ${account.platform} 的账户信息吗？此操作不可撤销。",
      confirmText: "确定删除",
      danger: true,
      onConfirm: () async {
        await StorageService().deleteAccount(account.id);
        if (!mounted) return;
        widget.onDeleteSuccess();
        MessageUtil.show(context, "条目已成功删除");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 动态感知屏幕宽度
    final bool isMobileLayout = AccountUiUtils.isMobileLayout(context);
    if (isMobileLayout) {
      return Scaffold(
        // 底部常驻操作栏
        bottomNavigationBar: _buildBottomActionBar(),
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              // 动画header
              SliverAppBar(
                expandedHeight: _isEditing ? null : 180.0, // 展开高度
                pinned: true, // 滚动到顶部后钉在顶端作为标准AppBar
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onClose, // 左上角返回
                ),
                title: _isEditing
                    ? const Text(
                        "编辑账户",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppText.section,
                        ),
                      )
                    : null,
                flexibleSpace: _isEditing
                    ? null
                    : FlexibleSpaceBar(
                        centerTitle: true,
                        // 编辑状态下隐藏标题，只读状态下显示平台名
                        title: _isEditing
                            ? null
                            : Text(
                                widget.account.platform,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppText.section,
                                ),
                              ),
                        background: Container(
                          color: AccountUiUtils.getStatusColor(
                            _currentStatus,
                          ).withValues(alpha: 0.05),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: _buildLargeLogo(widget.account),
                            ),
                          ),
                        ),
                      ),
                actions: [
                  // 右上角切换星标
                  IconButton(
                    onPressed: _toggleFavorite,
                    icon: Icon(
                      _favorite ? Icons.bookmark : Icons.bookmark_border,
                      color: _favorite
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: _favorite ? "取消星标" : "加入星标",
                  ),
                ],
              ),
              // 表单内容区
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_isEditing) ...[
                      _buildMobileEditingHeaderCard(),
                      const Divider(),
                    ],
                    // 分组1: 核心凭据
                    _buildEditableInfoRow("用户昵称", _nameController),
                    _buildEditableInfoRow("登录账号", _userIdController),
                    _buildEditableInfoRow("绑定邮箱", _emailController),
                    _buildEditableInfoRow(
                      "绑定手机",
                      _phoneController,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                    ),
                    AccountPasswordRow(
                      controller: _pswdController,
                      isEditing: _isEditing,
                      isVisible: _isPasswordVisible,
                      onToggleVisible: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                    const Divider(),
                    // 分组2: 平台与标记
                    _buildEditableUrlRow(), // 网址展示/编辑
                    _buildEditableTagsRow(), // 标签编辑器
                    const Divider(),
                    // 分组3: 辅助信息
                    _buildEditableInfoRow(
                      "生日",
                      _birthController,
                      isDateField: true,
                    ),
                    _buildEditableInfoRow(
                      "注册日期",
                      _signupDateController,
                      isDateField: true,
                    ),
                    _buildEditableRealNameRow(), // 实名勾选/展示
                    _buildEditableInfoRow("备注", _notesController, maxLines: 5),
                    _buildInfoRow(
                      "最后修改于",
                      DateUtil.format(widget.account.lastModified),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Column(
        children: [
          _buildDetailHeader(widget.account), // 头部
          const Divider(height: 1),
          Expanded(
            child: Form(
              key: _formKey, // 用于保存时的必填校验
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 分组1: 核心凭据
                  _buildEditableInfoRow("用户昵称", _nameController),
                  _buildEditableInfoRow("登录账号", _userIdController),
                  _buildEditableInfoRow("绑定邮箱", _emailController),
                  _buildEditableInfoRow(
                    "绑定手机",
                    _phoneController,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                  ),
                  AccountPasswordRow(
                    controller: _pswdController,
                    isEditing: _isEditing,
                    isVisible: _isPasswordVisible,
                    onToggleVisible: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  ),
                  const Divider(),
                  // 分组2: 平台与标记
                  _buildEditableUrlRow(), // 网址展示/编辑
                  _buildEditableTagsRow(), // 标签编辑器
                  const Divider(),
                  // 分组3: 辅助信息
                  _buildEditableInfoRow(
                    "生日",
                    _birthController,
                    isDateField: true,
                  ),
                  _buildEditableInfoRow(
                    "注册日期",
                    _signupDateController,
                    isDateField: true,
                  ),
                  _buildEditableRealNameRow(), // 实名勾选/展示
                  _buildEditableInfoRow("备注", _notesController, maxLines: 5),
                  _buildInfoRow(
                    "最后修改于",
                    DateUtil.format(widget.account.lastModified),
                  ),
                ],
              ),
            ),
          ),
          // 底部常驻操作栏(与移动端统一)
          _buildBottomActionBar(),
        ],
      );
    }
  }
}
