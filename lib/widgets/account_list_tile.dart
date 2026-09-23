/*
 * @Author: Thoma4
 * @Date: 2026-09-10 00:00:25
 * @LastEditTime: 2026-09-23 23:17:58
 * @Description: 经典样式账户列表
 */

import 'package:flutter/material.dart';

import '../models/account.dart';
import '../services/icon_service.dart';
import '../services/icon_store.dart';
import '../services/settings_service.dart';
import '../utils/app_text.dart';
import 'account_ui_utils.dart';

class AccountListTile extends StatefulWidget {
  final Account account;
  final bool isSelected; // 桌面端右侧面板选中高亮
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite; // 星标切换
  final bool isMobileLayout;

  const AccountListTile({
    super.key,
    required this.account,
    required this.isSelected,
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
    final icon = IconStore().iconFor(acc);
    if (icon != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          icon,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              AccountUiUtils.buildPlaceholder(acc.platform, color, 36, 16, 8),
        ),
      );
    }
    if (SettingsService().get('auto_fetch_icons') == 'true' &&
        acc.url.isNotEmpty) {
      IconService().fetchAndCacheIcon(acc.url).then((ok) {
        if (mounted && ok) setState(() {});
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
        height: AccountUiUtils.scaledFixed(context, 68), // 与卡片行高一致随字号档位放大
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
                    style: const TextStyle(fontSize: AppText.title),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppText.caption,
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
