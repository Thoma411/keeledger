/*
 * @Author: Thoma4
 * @Date: 2026-10-13 22:52:01
 * @LastEditTime: 2026-10-15 21:10:02
 * @Description: 常用信息管理页
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/preset.dart';
import '../services/storage_service.dart';
import '../utils/app_text.dart';
import '../utils/utils.dart';
import '../widgets/account_form_fields.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/preset_list_tile.dart';

// 进入常用信息管理页
Future<void> showPresetManagerPage(BuildContext context) {
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const PresetManagerPage()));
}

class PresetManagerPage extends StatefulWidget {
  const PresetManagerPage({super.key});

  @override
  State<PresetManagerPage> createState() => _PresetManagerPageState();
}

class _PresetManagerPageState extends State<PresetManagerPage> {
  List<Preset> _presets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  // 重新读取列表
  Future<void> _reload() async {
    final list = await StorageService().getAllPresets();
    if (!mounted) return;
    setState(() {
      _presets = list;
      _loading = false;
    });
  }

  // 复制内容
  void _copy(Preset preset) {
    Clipboard.setData(ClipboardData(text: preset.value));
    MessageUtil.show(
      context,
      preset.kind == PresetKind.password ? "密码已复制" : "已复制",
    );
  }

  // 新建
  Future<void> _create() async {
    final bool? created = await showDialog<bool>(
      context: context,
      builder: (_) => const _PresetCreateDialog(),
    );
    if (created != true || !mounted) return;
    await _reload();
    if (!mounted) return;
    MessageUtil.show(context, "添加成功");
  }

  // 删除
  void _delete(Preset preset) {
    AppDialogs.showConfirm(
      context,
      title: "删除『${preset.name}』？",
      message: "已填入账户中的内容不受影响。",
      confirmText: "删除",
      danger: true,
      onConfirm: () async {
        await StorageService().deletePreset(preset.id);
        if (!mounted) return;
        await _reload();
        if (!mounted) return;
        MessageUtil.show(context, "已删除");
      },
    );
  }

  // 空态引导
  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_outline,
            size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 24),
          const Text(
            "新建常用信息",
            style: TextStyle(
              fontSize: AppText.display,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "仅用于快捷填入账户字段，点击右上角'+'号新建",
            style: TextStyle(
              fontSize: AppText.body,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // 列表构建
  Widget _buildList() {
    return ListView.builder(
      itemCount: _presets.length,
      itemBuilder: (context, i) {
        final Preset p = _presets[i];
        return PresetListTile(
          key: ValueKey(p.id),
          preset: p,
          onCopy: () => _copy(p),
          onDelete: () => _delete(p),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("常用信息"),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _create,
            tooltip: "新建",
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: _loading
          ? const SizedBox.shrink()
          : (_presets.isEmpty ? _buildEmptyState() : _buildList()),
    );
  }
}

// 新建常用信息弹层
class _PresetCreateDialog extends StatefulWidget {
  const _PresetCreateDialog();

  @override
  State<_PresetCreateDialog> createState() => _PresetCreateDialogState();
}

class _PresetCreateDialogState extends State<_PresetCreateDialog> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  PresetKind? _kind; // 必须显式选择
  bool _valueVisible = false;
  bool get _isPassword => _kind == PresetKind.password;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  // 输入框填写校验
  Future<String?> _validate() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) return "请填写名称";
    if (_kind == null) return "请选择类型";
    final String value = _valueController.text;
    if (value.isEmpty) return "请填写内容";
    if (_kind == PresetKind.phone) {
      final String phone = value.trim();
      final bool invalid =
          !RegExp(r'^[0-9]+$').hasMatch(phone) || phone.length > 11;
      if (invalid) return "输入不合法";
    }
    if (await StorageService().isPresetNameExists(name)) {
      return "名称 '$name' 已存在";
    }
    return null;
  }

  // 不同kind的输入提示
  String? get _kindHint => switch (_kind) {
    PresetKind.phone => "一个合法的手机号应当仅包含数字，且不超过 11 位。",
    PresetKind.password => "尽管应用允许将密码添加为常用信息，但仍不建议这么做。",
    _ => null,
  };

  // 保存常用信息
  Future<void> _save() async {
    final String? error = await _validate();
    if (!mounted) return;
    if (error != null) {
      MessageUtil.show(context, error, isError: true);
      return;
    }
    await StorageService().savePreset(
      Preset(
        id: const Uuid().v4(),
        name: _nameController.text,
        kind: _kind!,
        value: _valueController.text,
        lastModified: DateTime.now().toIso8601String(),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final String? kindHint = _kindHint;
    return AlertDialog(
      title: const Text("新建常用信息"),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "名称",
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PresetKind>(
                initialValue: _kind,
                borderRadius: AppRadius.menu,
                decoration: const InputDecoration(
                  labelText: "类型",
                  isDense: true,
                ),
                items: [
                  for (final k in PresetKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (v) => setState(() => _kind = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _valueController,
                obscureText: _isPassword && !_valueVisible,
                decoration: InputDecoration(
                  labelText: "内容",
                  isDense: true,
                  suffixIcon: _isPassword
                      ? compactSuffixIcon(
                          Icon(
                            _valueVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 18,
                          ),
                          () => setState(() => _valueVisible = !_valueVisible),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                    maxHeight: 32,
                  ),
                ),
              ),
              if (kindHint != null) ...[
                const SizedBox(height: 12),
                Text(
                  kindHint,
                  style: TextStyle(
                    fontSize: AppText.caption,
                    color: _isPassword
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("取消"),
        ),
        ElevatedButton(onPressed: _save, child: const Text("保存")),
      ],
    );
  }
}
