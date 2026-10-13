/*
 * @Author: Thoma4
 * @Date: 2026-10-13 22:52:01
 * @LastEditTime: 2026-10-14 00:08:09
 * @Description: 经典样式常用信息行
 */

import 'package:flutter/material.dart';

import '../models/preset.dart';
import '../utils/app_text.dart';
import 'account_ui_utils.dart';

class PresetListTile extends StatefulWidget {
  final Preset preset;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const PresetListTile({
    super.key,
    required this.preset,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  State<PresetListTile> createState() => _PresetListTileState();
}

class _PresetListTileState extends State<PresetListTile> {
  // 密码明文显示(退出页面重置)
  bool _revealed = false;
  bool get _isPassword => widget.preset.kind == PresetKind.password;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.preset;
    final bool masked = _isPassword && !_revealed;

    return InkWell(
      // 仅密码行可点(切换明文/掩码)
      onTap: _isPassword ? () => setState(() => _revealed = !_revealed) : null,
      child: Container(
        height: AccountUiUtils.scaledFixed(context, 68), // 与账户经典行一致
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.6),
              width: 0.6,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 类型图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AccountUiUtils.presetKindIcon(p.kind),
                size: 20,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(fontSize: AppText.title),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    masked ? "••••••" : p.value, // 掩码固定6点
                    style: TextStyle(
                      fontSize: AppText.sub,
                      color: cs.onSurfaceVariant,
                      fontFamily: _isPassword ? 'Consolas' : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onCopy,
              visualDensity: VisualDensity.compact,
              tooltip: "复制",
              icon: Icon(Icons.copy_all_rounded, size: 18, color: cs.primary),
            ),
            IconButton(
              onPressed: widget.onDelete,
              visualDensity: VisualDensity.compact,
              tooltip: "删除",
              icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
            ),
          ],
        ),
      ),
    );
  }
}
