/*
 * @Author: Thoma4
 * @Date: 2026-09-10 00:00:25
 * @LastEditTime: 2026-09-10 00:30:07
 * @Description: 经典样式账户列表
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/account.dart';
import '../services/icon_service.dart';
import '../services/settings_service.dart';
import 'account_ui_utils.dart';

class AccountListTile extends StatefulWidget {
  final Account account;
  final bool isSelected; // 桌面端右侧面板选中高亮
  final String iconDirPath;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite; // 星标切换
  final bool isMobileLayout;

  const AccountListTile({
    super.key,
    required this.account,
    required this.isSelected,
    required this.iconDirPath,
    required this.onTap,
    required this.onToggleFavorite,
    this.isMobileLayout = false,
  });

  @override
  State<AccountListTile> createState() => _AccountListTileState();
}

class _AccountListTileState extends State<AccountListTile> {
  // 平台小图标(后台静默抓取逻辑与卡片一致)
  Widget _buildLogo(Account acc, Color color) {
    final String iconPath = p.join(widget.iconDirPath, "${acc.id}.png");
    final File iconFile = File(iconPath);
    if (iconFile.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          iconFile,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              AccountUiUtils.buildPlaceholder(acc.platform, color, 36, 16, 8),
        ),
      );
    }
    final bool isAutoFetchEnabled =
        SettingsService().get('auto_fetch_icons') == 'true';
    if (isAutoFetchEnabled && acc.url.isNotEmpty) {
      IconService().fetchAndCacheIcon(acc.id, acc.url).then((_) {
        if (mounted) setState(() {}); // 抓取成功后刷新UI
      });
    }
    return AccountUiUtils.buildPlaceholder(acc.platform, color, 36, 16, 8);
  }

  @override
  Widget build(BuildContext context) {
    final acc = widget.account;
    final cs = Theme.of(context).colorScheme;
    final Color statusColor = AccountUiUtils.getStatusColor(acc.status);

    // 副标题: 身份信息(昵称/ID/邮箱/手机), 多个时用"·"连接
    final parts = <String>[];
    if (acc.name.isNotEmpty || acc.userId.isNotEmpty) {
      parts.add(acc.name.isNotEmpty ? acc.name : acc.userId);
    }
    if (acc.email.isNotEmpty) parts.add(acc.email);
    if (acc.phone.isNotEmpty) parts.add(acc.phone);
    final String subtitle = parts.isEmpty
        ? (widget.isMobileLayout ? "" : "未填写身份信息")
        : parts.take(2).join(" · ");

    return InkWell(
      onTap: widget.onTap,
      child: Container(
        height: 68, // 与卡片行高一致
        decoration: BoxDecoration(
          color: widget.isSelected
              ? cs.primary.withValues(alpha: 0.06)
              : cs.surface,
          border: Border(
            // 行间细分隔线
            bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.6),
              width: 0.6,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildLogo(acc, statusColor),
            const SizedBox(width: 12),
            // 状态指示圆点
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 10),
            // 平台名+身份信息
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    acc.platform,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 星标快捷切换
            IconButton(
              onPressed: widget.onToggleFavorite,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                acc.favorite ? Icons.bookmark : Icons.bookmark_border,
                size: 20,
                color: acc.favorite
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              tooltip: acc.favorite ? "取消星标" : "加入星标",
            ),
          ],
        ),
      ),
    );
  }
}
