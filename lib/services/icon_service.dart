/*
 * @Author: Thoma4
 * @Date: 2026-06-15 16:34:15
 * @LastEditTime: 2026-09-23 23:10:39
 * @Description: 抓取网页icon并写入图标仓库
 */

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'icon_store.dart';

class IconService {
  static final IconService _instance = IconService._internal();
  factory IconService() => _instance;
  IconService._internal();

  final Set<String> _pendingFetches = {}; // 正在抓取的缓存键

  // 抓取并写入共享缓存(以域名为键, 同域账户共用); 返回是否成功
  // TODO(下一步): 抓取链替换为"直连站点"(apple-touch-icon → manifest → favicon)
  Future<bool> fetchAndCacheIcon(String rawUrl) async {
    final String key = IconStore.domainKey(rawUrl);
    if (key.isEmpty) return false;
    if (!_pendingFetches.add(key)) return false; // 同域正在抓取, 不重复发起

    try {
      final String domain = IconStore.hostOf(rawUrl);
      final List<String> apiPool = [
        "https://favicon.pub/$domain", // Favicon.pub
        "https://www.google.com/s2/favicons?sz=64&domain=$domain", // Google(备用)
      ];
      for (final String apiUrl in apiPool) {
        try {
          final response = await http
              .get(
                Uri.parse(apiUrl),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                },
              )
              .timeout(const Duration(seconds: 5));
          if (response.statusCode == 200 && response.bodyBytes.length > 100) {
            await IconStore().putCache(key, response.bodyBytes);
            debugPrint("IconService: 成功抓取图标($domain)");
            return true;
          }
        } catch (e) {
          debugPrint("IconService: 从 $apiUrl 抓取失败: $e");
        }
      }
      return false;
    } finally {
      _pendingFetches.remove(key);
    }
  }

  // 删除指定账户的专属图标
  Future<void> deleteIcon(String id) => IconStore().removeAccountIcon(id);

  // 清空自动抓取的共享缓存(用户指定的账户图标保留)
  Future<void> clearAllIcons() => IconStore().clearCache();
}
