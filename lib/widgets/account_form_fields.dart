/*
 * @Author: Thoma4
 * @Date: 2026-10-04 19:34:07
 * @LastEditTime: 2026-10-04 21:27:10
 * @Description: 账户表单字段(详情页与新账户页共用)
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
    suffixIconConstraints: const BoxConstraints(
      minWidth: 32,
      minHeight: 32,
      maxHeight: 32,
    ),
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
}) {
  return InputDecorator(
    decoration: accountFieldDecoration(context, readOnly: true),
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

// 单行字段: 标签+只读值/输入框
class AccountFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final bool isDateField;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;

  const AccountFieldRow({
    super.key,
    required this.label,
    required this.controller,
    required this.isEditing,
    this.isDateField = false,
    this.maxLines = 1,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMultiline = maxLines > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fieldLabel(context, label),
          const SizedBox(height: 4),
          if (!isEditing)
            readOnlyFieldValue(
              context,
              controller.text.isEmpty ? "-" : controller.text,
              style: const TextStyle(
                fontSize: AppText.body,
                fontWeight: FontWeight.w500,
              ),
              maxLines: isMultiline ? null : 1,
            )
          else
            TextFormField(
              controller: controller,
              maxLines: maxLines,
              // 行数随内容增长
              minLines: isMultiline ? 1 : null,
              inputFormatters: isDateField
                  ? [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\-./]')),
                      LengthLimitingTextInputFormatter(10),
                    ]
                  : inputFormatters,
              style: const TextStyle(
                fontSize: AppText.body,
                fontWeight: FontWeight.w500,
              ),
              decoration: accountFieldDecoration(
                context,
                suffixIcon: isDateField
                    ? _dateButton(context, controller)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  // 日期选择按钮
  Widget _dateButton(BuildContext context, TextEditingController controller) {
    return IconButton(
      icon: Icon(
        Icons.calendar_today,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
      onPressed: () => _pickDate(context, controller),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

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
class AccountPasswordRow extends StatelessWidget {
  final TextEditingController controller;
  final bool isEditing;
  final bool isVisible;
  final VoidCallback onToggleVisible;

  const AccountPasswordRow({
    super.key,
    required this.controller,
    required this.isEditing,
    required this.isVisible,
    required this.onToggleVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fieldLabel(context, "密码"),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: isEditing
                    ? TextFormField(
                        controller: controller,
                        // 闭眼时输入框也是遮蔽状态
                        obscureText: !isVisible,
                        style: const TextStyle(
                          fontSize: AppText.body,
                          fontFamily: 'Consolas',
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      )
                    : Text(
                        isVisible ? controller.text : "••••••••",
                        style: const TextStyle(
                          fontSize: AppText.body,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Consolas',
                        ),
                      ),
              ),
              IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                ),
                onPressed: onToggleVisible,
              ),
              // 复制按钮仅只读态显示
              if (!isEditing)
                IconButton(
                  icon: Icon(
                    Icons.copy_all_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: controller.text));
                    MessageUtil.show(context, "密码已复制");
                  },
                ),
            ],
          ),
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
    return Column(
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
                  onPressed: !isEditing ? () => onTagClicked?.call(tag) : null,
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
                      final List<String>? next = appendTag(context, tags, val);
                      if (next == null) return;
                      controller.clear();
                      onChanged(next);
                    },
                  ),
                ),
            ],
          ),
        ),
        if (isEditing && controller.text.isNotEmpty) _buildSuggestions(context),
      ],
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
                  if (next != null) onChanged(next);
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
