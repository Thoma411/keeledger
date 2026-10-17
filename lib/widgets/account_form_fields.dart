/*
 * @Author: Thoma4
 * @Date: 2026-10-04 19:34:07
 * @LastEditTime: 2026-10-18 00:01:33
 * @Description: 账户表单字段(详情页与新账户页共用)
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/preset.dart';
import '../utils/app_text.dart';
import '../utils/utils.dart';

// 输入框装饰: 只读态与编辑态共用, 保证两态行高一致
InputDecoration accountFieldDecoration(
  BuildContext context, {
  String? hint,
  Widget? suffixIcon,
  bool readOnly = false,
}) {
  return InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    border: InputBorder.none,
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1,
      ),
    ),
    hintText: hint,
    suffixIcon: suffixIcon,
    // 限制图标栏尺寸防止后缀图标把该行撑高
    suffixIconConstraints: _readOnlySuffixIconConstraints,
    filled: !readOnly, // 只读态不铺底色
  );
}

// 字段标签
Widget fieldLabel(BuildContext context, String text) {
  return Text(
    text,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: AppText.caption,
    ),
  );
}

// 只读值(与输入框共用装饰)
Widget readOnlyFieldValue(
  BuildContext context,
  String text, {
  TextStyle? style,
  int? maxLines,
  Widget? suffixIcon,
}) {
  return InputDecorator(
    decoration: accountFieldDecoration(
      context,
      readOnly: true,
      suffixIcon: suffixIcon,
    ),
    child: Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    ),
  );
}

// 追加标签
List<String>? appendTag(
  BuildContext context,
  List<String> tags,
  String raw, {
  int maxChars = 8,
}) {
  final String tag = raw.trim();
  if (tag.isEmpty || tags.contains(tag)) return null;
  if (tag.length > maxChars) {
    MessageUtil.show(context, "标签长度不能超过 $maxChars 个字");
    return null;
  }
  return [...tags, tag];
}

// 取某类型的候选(已排序)
List<Preset> presetCandidates(List<Preset> presets, PresetKind? kind) =>
    (kind == null) ? const [] : presets.where((p) => p.kind == kind).toList();

// 填入内容
void applyPreset(TextEditingController controller, Preset preset) {
  String value = preset.value;
  if (preset.kind == PresetKind.phone) {
    // 只留数字并限11位
    value = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.length > 11) value = value.substring(0, 11);
  }
  controller.text = value;
  controller.selection = TextSelection.collapsed(offset: value.length); // 光标置末尾
}

// 候选胶囊
class PresetChips extends StatelessWidget {
  final List<Preset> presets;
  final ValueChanged<Preset> onPick;
  const PresetChips({super.key, required this.presets, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in presets)
            ActionChip(
              label: Text(
                p.name,
                style: TextStyle(fontSize: AppText.label, color: cs.primary),
              ),
              onPressed: () => onPick(p),
              backgroundColor: cs.primary.withValues(alpha: 0.05),
            ),
        ],
      ),
    );
  }
}

// 字段行共用的快捷填入状态
mixin PresetFillMixin<T extends StatefulWidget> on State<T> {
  TextEditingController get presetFillController;
  List<Preset> get presetFillCandidates;

  // 是否处于可填入场景
  bool get presetFillEnabled => true;
  bool _expanded = false;
  bool _showFill = false;
  bool get _canFill =>
      presetFillEnabled &&
      presetFillCandidates.isNotEmpty &&
      presetFillController.text.isEmpty;

  @override
  void initState() {
    super.initState();
    presetFillController.addListener(_onTextChanged);
    _showFill = _canFill;
  }

  @override
  void dispose() {
    presetFillController.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _showFill = _canFill;
    if (!_showFill) _expanded = false; // 入口消失时收起已展开的胶囊
  }

  // 只在入口可见性变化时重建
  void _onTextChanged() {
    if (!mounted) return;
    final bool canFill = _canFill;
    if (canFill == _showFill) return;
    setState(() {
      _showFill = canFill;
      if (!canFill) _expanded = false;
    });
  }

  // 右侧入口
  Widget? suffixFillButton(BuildContext context, {bool readOnlyStyle = false}) {
    if (!_showFill) return null;
    return compactSuffixIcon(
      Icon(
        Icons.expand_more,
        size: readOnlyStyle ? _readOnlyIconSize : _editIconSize,
        color: Theme.of(context).colorScheme.primary,
      ),
      () => setState(() => _expanded = !_expanded),
      size: readOnlyStyle ? _readOnlyIconButtonSize : _editIconButtonSize,
    );
  }

  // 下方候选胶囊
  Widget? fillChips(BuildContext context) {
    if (!_expanded) return null;
    return PresetChips(
      presets: presetFillCandidates,
      onPick: (preset) {
        applyPreset(presetFillController, preset);
        setState(() => _expanded = false);
      },
    );
  }
}

// 新建账户p1-必填字段
class AccountRequiredFields extends StatelessWidget {
  final TextEditingController platform, name, userId, pswd, email, phone;
  final bool passwordVisible;
  final VoidCallback onTogglePassword;
  final List<Preset> presets; // 常用信息

  const AccountRequiredFields({
    super.key,
    required this.platform,
    required this.name,
    required this.userId,
    required this.pswd,
    required this.email,
    required this.phone,
    required this.passwordVisible,
    required this.onTogglePassword,
    this.presets = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountFieldRow(
          label: "平台名称（必填）",
          controller: platform,
          isEditing: true,
          editingStyle: true,
        ),
        const FieldHint("以下至少填写一项"),
        AccountFieldRow(
          label: "用户昵称",
          controller: name,
          isEditing: true,
          editingStyle: true,
          presetKind: PresetKind.nickname,
          presets: presets,
        ),
        AccountFieldRow(
          label: "用户ID",
          controller: userId,
          isEditing: true,
          editingStyle: true,
        ),
        AccountPasswordRow(
          controller: pswd,
          isEditing: true,
          isVisible: passwordVisible,
          onToggleVisible: onTogglePassword,
          editingStyle: true,
          presetKind: PresetKind.password,
          presets: presets,
        ),
        AccountFieldRow(
          label: "绑定邮箱",
          controller: email,
          isEditing: true,
          editingStyle: true,
          presetKind: PresetKind.email,
          presets: presets,
        ),
        AccountFieldRow(
          label: "绑定手机",
          controller: phone,
          isEditing: true,
          editingStyle: true,
          presetKind: PresetKind.phone,
          presets: presets,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
      ],
    );
  }
}

// 新建账户p2-选填字段
class AccountOptionalFields extends StatelessWidget {
  final TextEditingController url, tags, birth, signup, notes;
  final List<String> tagList;
  final ValueChanged<List<String>> onTagsChanged;
  final Set<String> globalTags;
  final int status;
  final ValueChanged<int> onStatusChanged;
  final bool realName;
  final ValueChanged<bool> onRealNameChanged;

  const AccountOptionalFields({
    super.key,
    required this.url,
    required this.tags,
    required this.birth,
    required this.signup,
    required this.notes,
    required this.tagList,
    required this.onTagsChanged,
    required this.globalTags,
    required this.status,
    required this.onStatusChanged,
    required this.realName,
    required this.onRealNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldHint("以下均为选填项，可跳过"),
        AccountFieldRow(
          label: "网址",
          controller: url,
          isEditing: true,
          editingStyle: true,
        ),
        AccountTagsRow(
          tags: tagList,
          controller: tags,
          isEditing: true,
          globalTags: globalTags,
          onChanged: onTagsChanged,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DropdownButtonFormField<int>(
            initialValue: status,
            borderRadius: AppRadius.menu,
            decoration: const InputDecoration(labelText: "账户状态", isDense: true),
            items: const [
              DropdownMenuItem(value: 1, child: Text("使用中")),
              DropdownMenuItem(value: 0, child: Text("未注册")),
              DropdownMenuItem(value: 2, child: Text("已注销")),
              DropdownMenuItem(value: 3, child: Text("无法使用")),
            ],
            onChanged: (v) => onStatusChanged(v ?? 1),
          ),
        ),
        _buildDateFields(context),
        CheckboxListTile(
          title: const Text("是否已实名", style: TextStyle(fontSize: AppText.body)),
          value: realName,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => onRealNameChanged(v ?? false),
        ),
        AccountFieldRow(
          label: "备注",
          controller: notes,
          isEditing: true,
          maxLines: 5,
          editingStyle: true,
        ),
      ],
    );
  }

  // 生日/注册日期
  Widget _buildDateFields(BuildContext context) {
    final Widget birthField = AccountFieldRow(
      label: "生日",
      controller: birth,
      isEditing: true,
      isDateField: true,
      editingStyle: true,
    );
    final Widget signupField = AccountFieldRow(
      label: "注册日期",
      controller: signup,
      isEditing: true,
      isDateField: true,
      editingStyle: true,
    );
    // 字号过大时显示为两行
    if (MediaQuery.textScalerOf(context).scale(1.0) > 1.0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [birthField, signupField],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: birthField),
        const SizedBox(width: 12),
        Expanded(child: signupField),
      ],
    );
  }
}

// 分组说明
class FieldHint extends StatelessWidget {
  final String text;
  const FieldHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
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
}

// 单行字段: 标签+只读值/输入框
class AccountFieldRow extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final bool isDateField;
  // true=编辑样式; false=只读样式
  final bool editingStyle;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final PresetKind? presetKind; // 需要快捷填入时传入类型
  final List<Preset> presets; // 常用信息

  const AccountFieldRow({
    super.key,
    required this.label,
    required this.controller,
    required this.isEditing,
    this.isDateField = false,
    this.editingStyle = false,
    this.maxLines = 1,
    this.inputFormatters,
    this.presetKind,
    this.presets = const [],
  });

  @override
  State<AccountFieldRow> createState() => _AccountFieldRowState();
}

class _AccountFieldRowState extends State<AccountFieldRow>
    with PresetFillMixin<AccountFieldRow> {
  @override
  TextEditingController get presetFillController => widget.controller;

  @override
  List<Preset> get presetFillCandidates =>
      presetCandidates(widget.presets, widget.presetKind);

  @override
  bool get presetFillEnabled => widget.isEditing;

  @override
  Widget build(BuildContext context) {
    final bool isMultiline = widget.maxLines > 1;
    final Widget? chips = fillChips(context);
    // 编辑样式
    if (widget.editingStyle) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: widget.controller,
              maxLines: widget.maxLines,
              minLines: isMultiline ? 1 : null,
              inputFormatters: _formatters,
              style: const TextStyle(
                fontSize: AppText.body,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: widget.label,
                isDense: true,
                alignLabelWithHint: isMultiline,
                suffixIcon: _buildSuffix(context, readOnlyStyle: false),
                suffixIconConstraints: _editSuffixIconConstraints,
              ),
            ),
            ?chips,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fieldLabel(context, widget.label),
          const SizedBox(height: 4),
          if (!widget.isEditing)
            readOnlyFieldValue(
              context,
              widget.controller.text.isEmpty ? "-" : widget.controller.text,
              style: const TextStyle(
                fontSize: AppText.body,
                fontWeight: FontWeight.w500,
              ),
              maxLines: isMultiline ? null : 1,
            )
          else
            TextFormField(
              controller: widget.controller,
              maxLines: widget.maxLines,
              // 行数随内容增长
              minLines: isMultiline ? 1 : null,
              inputFormatters: _formatters,
              style: const TextStyle(
                fontSize: AppText.body,
                fontWeight: FontWeight.w500,
              ),
              decoration: accountFieldDecoration(
                context,
                suffixIcon: _buildSuffix(context, readOnlyStyle: true),
              ),
            ),
          ?chips,
        ],
      ),
    );
  }

  // 后缀图标
  Widget? _buildSuffix(BuildContext context, {required bool readOnlyStyle}) {
    final Widget? fill = suffixFillButton(
      context,
      readOnlyStyle: readOnlyStyle,
    );
    final List<Widget> buttons = [
      ?fill,
      if (widget.isDateField)
        _dateButton(context, widget.controller, readOnlyStyle: readOnlyStyle),
    ];
    if (buttons.isEmpty) return null;
    if (buttons.length == 1) return buttons.first;
    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  // 日期字段限制可输入字符
  List<TextInputFormatter>? get _formatters => widget.isDateField
      ? [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9\-./]')),
          LengthLimitingTextInputFormatter(10),
        ]
      : widget.inputFormatters;

  // 日期选择按钮
  Widget _dateButton(
    BuildContext context,
    TextEditingController controller, {
    required bool readOnlyStyle,
  }) {
    return compactSuffixIcon(
      Icon(
        Icons.calendar_today,
        size: readOnlyStyle ? _readOnlyIconSize : 16,
        color: Theme.of(context).colorScheme.primary,
      ),
      () => _pickDate(context, controller),
      size: readOnlyStyle ? _readOnlyIconButtonSize : _editIconButtonSize,
    );
  }
}

// 后缀图标按钮
Widget compactSuffixIcon(
  Widget icon,
  VoidCallback onPressed, {
  double size = _editIconButtonSize,
}) {
  return IconButton(
    icon: icon,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(
      minimumSize: Size.square(size),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

// 后缀图标尺寸
const double _editIconButtonSize = 32; // 编辑样式-热区
const double _editIconSize = 18; // 编辑样式-图标
const double _readOnlyIconButtonSize = 36; // 只读样式-热区
const double _readOnlyIconSize = 16; // 只读样式-图标

// 只读样式后缀图标位尺寸
const BoxConstraints _readOnlySuffixIconConstraints = BoxConstraints(
  minWidth: _readOnlyIconButtonSize,
  minHeight: _readOnlyIconButtonSize,
  maxHeight: _readOnlyIconButtonSize,
);

// 编辑样式后缀图标位尺寸
const BoxConstraints _editSuffixIconConstraints = BoxConstraints(
  minWidth: _editIconButtonSize,
  minHeight: _editIconButtonSize,
  maxHeight: _editIconButtonSize,
);

// 日历选择器
Future<void> _pickDate(
  BuildContext context,
  TextEditingController controller,
) async {
  final DateTime initialDate =
      DateTime.tryParse(controller.text) ?? DateTime.now();
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(1900),
    lastDate: DateTime(2100),
    helpText: '选择日期',
    cancelText: '取消',
    confirmText: '确定',
  );
  if (picked != null) {
    controller.text = DateFormat('yyyy-MM-dd').format(picked);
  }
}

// 密码行
class AccountPasswordRow extends StatefulWidget {
  final TextEditingController controller;
  final bool isEditing;
  final bool isVisible;
  final VoidCallback onToggleVisible;
  // true=编辑样式; false=只读样式
  final bool editingStyle;
  final PresetKind? presetKind; // 需要快捷填入时传入类型
  final List<Preset> presets;

  const AccountPasswordRow({
    super.key,
    required this.controller,
    required this.isEditing,
    required this.isVisible,
    required this.onToggleVisible,
    this.editingStyle = false,
    this.presetKind,
    this.presets = const [],
  });

  @override
  State<AccountPasswordRow> createState() => _AccountPasswordRowState();
}

class _AccountPasswordRowState extends State<AccountPasswordRow>
    with PresetFillMixin<AccountPasswordRow> {
  @override
  TextEditingController get presetFillController => widget.controller;

  @override
  List<Preset> get presetFillCandidates =>
      presetCandidates(widget.presets, widget.presetKind);

  @override
  bool get presetFillEnabled => widget.isEditing;

  // 显示/隐藏切换按钮
  Widget _eyeButton({required bool readOnlyStyle}) => compactSuffixIcon(
    Icon(
      widget.isVisible ? Icons.visibility : Icons.visibility_off,
      size: readOnlyStyle ? _readOnlyIconSize : _editIconSize,
    ),
    widget.onToggleVisible,
    size: readOnlyStyle ? _readOnlyIconButtonSize : _editIconButtonSize,
  );

  // 复制按钮(仅只读态)
  Widget _copyButton(BuildContext context, {required bool readOnlyStyle}) =>
      compactSuffixIcon(
        Icon(
          Icons.copy_all_rounded,
          size: readOnlyStyle ? _readOnlyIconSize : _editIconSize,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        () {
          Clipboard.setData(ClipboardData(text: widget.controller.text));
          MessageUtil.show(context, "密码已复制");
        },
        size: readOnlyStyle ? _readOnlyIconButtonSize : _editIconButtonSize,
      );

  // 后缀图标
  Widget _buildSuffix(BuildContext context, {required bool readOnlyStyle}) {
    final List<Widget> buttons = [
      ?suffixFillButton(context, readOnlyStyle: readOnlyStyle),
      if (!widget.isEditing) _copyButton(context, readOnlyStyle: readOnlyStyle),
      _eyeButton(readOnlyStyle: readOnlyStyle),
    ];
    return buttons.length == 1
        ? buttons.first
        : Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  @override
  Widget build(BuildContext context) {
    final Widget? chips = fillChips(context);
    // 编辑样式
    if (widget.editingStyle) {
      final Widget? fill = suffixFillButton(context);
      final Widget eye = _eyeButton(readOnlyStyle: false);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: widget.controller,
              obscureText: !widget.isVisible,
              style: const TextStyle(
                fontSize: AppText.body,
                fontFamily: 'Consolas',
              ),
              decoration: InputDecoration(
                labelText: "密码",
                isDense: true,
                suffixIcon: (fill == null)
                    ? eye
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [fill, eye],
                      ),
                suffixIconConstraints: _editSuffixIconConstraints,
              ),
            ),
            ?chips,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fieldLabel(context, "密码"),
          const SizedBox(height: 4),
          if (!widget.isEditing)
            readOnlyFieldValue(
              context,
              // 闭眼时输入框也是遮蔽状态
              widget.isVisible ? widget.controller.text : "••••••••",
              style: const TextStyle(
                fontSize: AppText.body,
                fontWeight: FontWeight.w500,
                fontFamily: 'Consolas',
              ),
              maxLines: 1,
              suffixIcon: _buildSuffix(context, readOnlyStyle: true),
            )
          else
            TextFormField(
              controller: widget.controller,
              obscureText: !widget.isVisible,
              style: const TextStyle(
                fontSize: AppText.body,
                fontFamily: 'Consolas',
              ),
              decoration: accountFieldDecoration(
                context,
                suffixIcon: _buildSuffix(context, readOnlyStyle: true),
              ),
            ),
          ?chips,
        ],
      ),
    );
  }
}

// 标签行
class AccountTagsRow extends StatelessWidget {
  final List<String> tags;
  final TextEditingController controller;
  final bool isEditing;
  final Set<String> globalTags;
  final ValueChanged<List<String>> onChanged;
  final ValueChanged<String>? onTagClicked;

  const AccountTagsRow({
    super.key,
    required this.tags,
    required this.controller,
    required this.isEditing,
    required this.globalTags,
    required this.onChanged,
    this.onTagClicked,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 标签块自带边框
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fieldLabel(context, "标签 (回车切分)"),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isEditing
                  ? Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isEditing
                  ? Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                    )
                  : null,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...tags.map(
                  (tag) => InputChip(
                    label: Text(
                      tag,
                      style: const TextStyle(fontSize: AppText.label),
                    ),
                    shape: const StadiumBorder(),
                    onDeleted: isEditing
                        ? () => onChanged([...tags]..remove(tag))
                        : null,
                    onPressed: !isEditing
                        ? () => onTagClicked?.call(tag)
                        : null,
                    deleteIcon: const Icon(Icons.cancel, size: 14),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (isEditing)
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: "新标签...",
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                      style: const TextStyle(fontSize: AppText.sub),
                      onSubmitted: (val) {
                        final List<String>? next = appendTag(
                          context,
                          tags,
                          val,
                        );
                        if (next == null) return;
                        controller.clear();
                        onChanged(next);
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (isEditing && controller.text.isNotEmpty)
            _buildSuggestions(context),
        ],
      ),
    );
  }

  // 已有标签的补全建议
  Widget _buildSuggestions(BuildContext context) {
    final List<String> suggestions = globalTags
        .where(
          (t) =>
              t.toLowerCase().contains(controller.text.toLowerCase()) &&
              !tags.contains(t),
        )
        .toList();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        children: suggestions
            .take(5)
            .map(
              (s) => ActionChip(
                label: Text(
                  s,
                  style: TextStyle(
                    fontSize: AppText.label,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onPressed: () {
                  final List<String>? next = appendTag(context, tags, s);
                  if (next == null) return;
                  controller.clear(); // 采纳建议后清空输入框
                  onChanged(next);
                },
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.05),
              ),
            )
            .toList(),
      ),
    );
  }
}
