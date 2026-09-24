/*
 * @Author: Thoma4
 * @Date: 2026-09-23 22:36:44
 * @LastEditTime: 2026-09-24 21:16:20
 * @Description: 图标仓库
 */

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/account.dart';
import '../utils/icon_codec.dart';
import 'storage_service.dart';

class IconStore {
  static final IconStore _instance = IconStore._internal();
  factory IconStore() => _instance;
  IconStore._internal();

  // 账户专属图标(用户指定)
  final Map<String, Uint8List> _accountIcons = {};
  // 共享缓存(键: domain:host)
  final Map<String, Uint8List> _cache = {};

  // 域名缓存键
  static String domainKey(String rawUrl) {
    final String host = hostOf(rawUrl);
    return host.isEmpty ? "" : "domain:$host";
  }

  // 提取主机名
  static String hostOf(String rawUrl) {
    try {
      String url = rawUrl.trim().toLowerCase();
      if (url.isEmpty) return "";
      if (!url.startsWith("http")) url = "http://$url";
      String host = Uri.parse(url).host;
      if (host.startsWith("www.")) host = host.substring(4);
      return host;
    } catch (_) {
      return "";
    }
  }

  // 解锁后载入内存
  Future<void> load() async {
    _accountIcons.clear();
    _cache.clear();
    if (!await StorageService().isDatabaseExists()) return;
    final db = await StorageService().database;
    for (final row in await db.query('account_icons')) {
      _accountIcons[row['id'] as String] = _blob(row['data']);
    }
    for (final row in await db.query('icon_cache')) {
      _cache[row['key'] as String] = _blob(row['data']);
    }
  }

  @visibleForTesting
  void reset() {
    _accountIcons.clear();
    _cache.clear();
  }

  // 解析应显示的图标(账户专属->域名缓存)
  Uint8List? iconFor(Account acc) {
    final Uint8List? own = _accountIcons[acc.id];
    if (own != null) return own;
    final String dk = domainKey(acc.url);
    return dk.isEmpty ? null : _cache[dk];
  }

  // 指定账户图标
  Future<void> setAccountIcon(Account acc, Uint8List raw) async {
    final Uint8List data = await IconCodec.normalize(raw);
    _accountIcons[acc.id] = data;
    await _put(await StorageService().database, 'account_icons', {
      'id': acc.id,
      'data': data,
    });
    await StorageService().bumpRevision(); // 更新修订号
  }

  // 写入共享缓存
  Future<void> putCache(String key, Uint8List raw) async {
    if (key.isEmpty) return;
    final Uint8List data = await IconCodec.normalize(raw);
    _cache[key] = data;
    if (!await StorageService().isDatabaseExists()) return;
    await _put(await StorageService().database, 'icon_cache', {
      'key': key,
      'data': data,
    });
  }

  // 清理账户专属图标(共享缓存保留)
  Future<void> removeAccountIcon(String id) async {
    _accountIcons.remove(id);
    if (!await StorageService().isDatabaseExists()) return;
    await (await StorageService().database).delete(
      'account_icons',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 清空共享缓存(账户专属图标保留)
  Future<void> clearCache() async {
    _cache.clear();
    if (!await StorageService().isDatabaseExists()) return;
    await (await StorageService().database).delete('icon_cache');
  }

  Future<void> _put(Database db, String table, Map<String, Object?> row) async {
    await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Uint8List _blob(dynamic value) => value is Uint8List
      ? value
      : Uint8List.fromList((value as List).cast<int>());
}
