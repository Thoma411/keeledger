/*
 * @Author: Thoma4
 * @Date: 2026-09-23 22:36:44
 * @LastEditTime: 2026-09-23 23:24:05
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

  // 账户专属图标(用户从已安装应用/本地文件指定), 清缓存不会动它
  final Map<String, Uint8List> _accountIcons = {};
  // 共享缓存(自动抓取或平台复用), 键为 domain:host / name:platform
  final Map<String, Uint8List> _cache = {};

  // 域名缓存键
  static String domainKey(String rawUrl) {
    final String host = hostOf(rawUrl);
    return host.isEmpty ? "" : "domain:$host";
  }

  // 平台名缓存键(规范化后, 同平台多账号共用)
  static String platformKey(String platform) =>
      "name:${normalizePlatform(platform)}";

  // 提取并规范化主机名
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

  // 规范化平台名: 去掉尾部的 _1/-2/(3)/副本 等区分后缀
  static String normalizePlatform(String platform) {
    final String src = platform.trim().toLowerCase();
    final String stripped = src
        .replaceAll(RegExp(r'[\s_\-－()（）]*\d+[)）]*$'), '')
        .replaceAll(RegExp(r'[\s_\-－()（）]*(副本|小号)$'), '')
        .trim();
    return stripped.isEmpty ? src : stripped;
  }

  // 解锁后调用: 一次性把两张表读进内存
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

  // 解析当前应显示的图标: 账户专属 → 域名缓存 → 平台名缓存
  Uint8List? iconFor(Account acc) {
    final Uint8List? own = _accountIcons[acc.id];
    if (own != null) return own;
    final String dk = domainKey(acc.url);
    if (dk.isNotEmpty && _cache[dk] != null) return _cache[dk];
    return _cache[platformKey(acc.platform)];
  }

  // 用户指定该账户的图标, 同时按平台名记一份供同平台其他账户复用
  Future<void> setAccountIcon(Account acc, Uint8List raw) async {
    final Uint8List data = await IconCodec.normalize(raw);
    _accountIcons[acc.id] = data;
    final String pk = platformKey(acc.platform);
    _cache[pk] = data;
    final db = await StorageService().database;
    await _put(db, 'account_icons', {'id': acc.id, 'data': data});
    await _put(db, 'icon_cache', {'key': pk, 'data': data});
  }

  // 写入共享缓存(自动抓取结果)
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

  // 账户被删除时清理其专属图标(共享缓存保留, 其他账户可能还在用)
  Future<void> removeAccountIcon(String id) async {
    _accountIcons.remove(id);
    if (!await StorageService().isDatabaseExists()) return;
    await (await StorageService().database).delete(
      'account_icons',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 清空自动抓取的共享缓存(用户指定的账户图标保留)
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
