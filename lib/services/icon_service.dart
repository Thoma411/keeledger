/*
 * @Author: Thoma4
 * @Date: 2026-06-15 16:34:15
 * @LastEditTime: 2026-09-24 23:26:02
 * @Description: 抓取网页icon并写入图标仓库
 */

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'icon_store.dart';
import 'settings_service.dart';

class IconService {
  static final IconService _instance = IconService._internal();
  factory IconService() => _instance;
  IconService._internal();

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const Duration _timeout = Duration(seconds: 6);
  static const int _maxHtmlBytes = 300 * 1024; // 首页只读前300KB

  final Set<String> _pendingFetches = {}; // 正在抓取的域名键
  final Set<String> _failedKeys = {}; // 本次启动已失败的域名键

  // 抓取图标并写入共享缓存(键为域名)
  Future<bool> fetchAndCacheIcon(String rawUrl) async {
    final String key = IconStore.domainKey(rawUrl);
    if (key.isEmpty) return false;
    if (_failedKeys.contains(key)) return false; // 失败则本次启动不再重试
    if (!_pendingFetches.add(key)) return false; // 同域抓取时不重复发起

    try {
      final String host = IconStore.hostOf(rawUrl);
      final String template =
          (SettingsService().get('icon_source_template') ?? '').trim();
      final String? customUrl = customSourceUrl(template, host);
      if (customUrl != null) {
        debugPrint("IconService: $host 使用自定义图标源 $customUrl");
      } else {
        if (template.isNotEmpty) {
          debugPrint("IconService: 图标源模板缺少 {domain}, 已忽略");
        }
        debugPrint("IconService: $host 直连站点抓取");
      }

      final List<({String url, String source})> candidates = [
        if (customUrl != null) (url: customUrl, source: "自定义源"),
        ...await _siteCandidates(host),
      ];
      for (final c in candidates) {
        final Uint8List? bytes = await _downloadIcon(c.url);
        if (bytes == null) continue;
        try {
          await IconStore().putCache(key, bytes);
          debugPrint("IconService: $host 命中(${c.source}) ${c.url}");
          return true;
        } catch (e) {
          debugPrint("IconService: ${c.url} 不是可用图片: $e");
        }
      }
      _failedKeys.add(key);
      debugPrint("IconService: $host 未找到可用图标, 本次启动不再重试");
      return false;
    } finally {
      _pendingFetches.remove(key);
    }
  }

  // 自定义源地址
  @visibleForTesting
  static String? customSourceUrl(String? template, String host) {
    final String t = (template ?? '').trim();
    if (t.isEmpty || !t.contains('{domain}')) return null;
    return t.replaceAll('{domain}', host);
  }

  // 直连站点候选
  Future<List<({String url, String source})>> _siteCandidates(
    String host,
  ) async {
    final List<({String url, String source})> result = [];
    final String? html = await _downloadText('https://$host/');
    if (html != null) {
      final Uri base = Uri.parse('https://$host/');
      result.addAll(
        parseHtmlIcons(html, base).map((u) => (url: u, source: "网页声明")),
      );
      final String? manifestUrl = parseManifestUrl(html, base);
      if (manifestUrl != null) {
        final String? json = await _downloadText(manifestUrl);
        if (json != null) {
          result.addAll(
            parseManifestIcons(
              json,
              Uri.parse(manifestUrl),
            ).map((u) => (url: u, source: "manifest")),
          );
        }
      }
    }
    result.addAll([
      (url: "https://$host/apple-touch-icon.png", source: "约定路径"),
      (url: "https://$host/favicon.ico", source: "约定路径"),
    ]);
    return result;
  }

  // 解析图标声明
  @visibleForTesting
  static List<String> parseHtmlIcons(String html, Uri base) {
    final List<({String href, int px})> apple = [];
    final List<({String href, int px})> others = [];
    for (final match in RegExp(
      r'<link\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final String tag = match.group(0)!;
      final String rel = (_attr(tag, 'rel') ?? '').toLowerCase();
      final String? href = _attr(tag, 'href');
      if (href == null || href.isEmpty || rel.isEmpty) continue;
      final ({String href, int px}) link = (
        href: href,
        px: _sizeToPx(_attr(tag, 'sizes') ?? ''),
      );
      if (rel.contains('apple-touch-icon')) {
        apple.add(link);
      } else if (rel.contains('icon') && !rel.contains('mask-icon')) {
        others.add(link);
      }
    }
    return _resolveAll([..._bySizeDesc(apple), ..._bySizeDesc(others)], base);
  }

  // 解析manifest地址
  @visibleForTesting
  static String? parseManifestUrl(String html, Uri base) {
    for (final match in RegExp(
      r'<link\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final String tag = match.group(0)!;
      final String rel = (_attr(tag, 'rel') ?? '').toLowerCase();
      final String? href = _attr(tag, 'href');
      if (rel.contains('manifest') && href != null && href.isNotEmpty) {
        return base.resolve(href).toString();
      }
    }
    return null;
  }

  // 解析manifest图标
  @visibleForTesting
  static List<String> parseManifestIcons(String jsonStr, Uri base) {
    try {
      final dynamic data = jsonDecode(jsonStr);
      if (data is! Map || data['icons'] is! List) return const [];
      final List<({String href, int px})> links = [];
      for (final dynamic item in data['icons'] as List) {
        if (item is! Map) continue;
        final dynamic src = item['src'];
        if (src is! String || src.isEmpty) continue;
        links.add((href: src, px: _sizeToPx('${item['sizes'] ?? ''}')));
      }
      return _resolveAll(_bySizeDesc(links), base);
    } catch (e) {
      debugPrint("IconService: manifest 解析失败: $e");
      return const [];
    }
  }

  static List<({String href, int px})> _bySizeDesc(
    List<({String href, int px})> links,
  ) {
    return [...links]..sort((a, b) => b.px.compareTo(a.px));
  }

  // 转绝对路径并去重
  static List<String> _resolveAll(
    List<({String href, int px})> links,
    Uri base,
  ) {
    final List<String> out = [];
    for (final link in links) {
      if (link.href.toLowerCase().endsWith('.svg')) continue; // 跳过矢量图
      final String url = link.href.startsWith('data:')
          ? link.href
          : base.resolve(link.href).toString();
      if (!out.contains(url)) out.add(url);
    }
    return out;
  }

  // 取标签属性
  static String? _attr(String tag, String name) {
    final match = RegExp(
      '(?:^|\\s)$name\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\'|([^\\s>]+))',
      caseSensitive: false,
    ).firstMatch(tag);
    if (match == null) return null;
    return match.group(1) ?? match.group(2) ?? match.group(3);
  }

  // 尺寸解析(无尺寸->0)
  static int _sizeToPx(String sizes) {
    final match = RegExp(r'(\d+)\s*[xX×]\s*(\d+)').firstMatch(sizes);
    if (match == null) return 0;
    final int w = int.parse(match.group(1)!);
    final int h = int.parse(match.group(2)!);
    return w < h ? w : h;
  }

  // 下载图片
  Future<Uint8List?> _downloadIcon(String url) async {
    if (url.startsWith('data:')) {
      final int comma = url.indexOf(',');
      if (comma < 0 || !url.substring(0, comma).contains('base64')) return null;
      try {
        return base64Decode(url.substring(comma + 1));
      } catch (_) {
        return null;
      }
    }
    final http.Response? res = await _get(url);
    if (res == null || res.statusCode != 200) return null;
    final Uint8List bytes = res.bodyBytes;
    if (bytes.length < 60) return null;
    if (bytes[0] == 0x3C) return null; // '<': 200 的 HTML 错误页
    return bytes;
  }

  Future<http.Response?> _get(String url) async {
    try {
      return await http
          .get(Uri.parse(url), headers: {'User-Agent': _userAgent})
          .timeout(_timeout);
    } catch (e) {
      debugPrint("IconService: 请求失败 $url: $e");
      return null;
    }
  }

  // 读取文本
  Future<String?> _downloadText(String url) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url))
        ..headers['User-Agent'] = _userAgent;
      final response = await client.send(request).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final builder = BytesBuilder();
      await for (final chunk in response.stream.timeout(_timeout)) {
        builder.add(chunk);
        if (builder.length >= _maxHtmlBytes) break;
      }
      return utf8.decode(builder.takeBytes(), allowMalformed: true);
    } catch (e) {
      debugPrint("IconService: 读取失败 $url: $e");
      return null;
    } finally {
      client.close();
    }
  }

  // 删除账户图标
  Future<void> deleteIcon(String id) => IconStore().removeAccountIcon(id);

  // 清空共享缓存(失败记录一并重置)
  Future<void> clearAllIcons() async {
    _failedKeys.clear();
    await IconStore().clearCache();
  }
}
