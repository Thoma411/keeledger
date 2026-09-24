/*
 * @Author: Thoma4
 * @Date: 2026-09-24 00:03:15
 * @LastEditTime: 2026-09-24 21:19:35
 * @Description: 图标抓取测试
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/services/icon_service.dart';

void main() {
  test('自定义图标源: 必须含 {domain} 才生效', () {
    expect(
      IconService.customSourceUrl('https://my.icon/{domain}.png', 'github.com'),
      'https://my.icon/github.com.png',
    );
    expect(
      IconService.customSourceUrl('  https://my.icon/?d={domain}  ', 'a.com'),
      'https://my.icon/?d=a.com',
    );
    expect(IconService.customSourceUrl('', 'a.com'), isNull); // 留空=直连
    expect(IconService.customSourceUrl(null, 'a.com'), isNull);
    expect(
      IconService.customSourceUrl('https://my.icon/i.png', 'a.com'),
      isNull,
    );
  });

  test('解析HTML图标: apple-touch-icon 优先, 组内按尺寸降序', () {
    const String html = '''
<html><head>
<link rel="icon" href="/favicon-32.png" sizes="32x32">
<link rel="stylesheet" href="/style.css">
<link rel="apple-touch-icon" href="/apple-touch-icon.png" sizes="180x180">
<link rel="apple-touch-icon" href="https://cdn.example.com/big.png" sizes="512x512">
<link rel="shortcut icon" sizes="16x16" href="favicon-16.png">
<link rel="mask-icon" href="/mask.svg">
</head><body></body></html>''';
    expect(
      IconService.parseHtmlIcons(
        html,
        Uri.parse('https://www.example.com/page'),
      ),
      [
        'https://cdn.example.com/big.png',
        'https://www.example.com/apple-touch-icon.png',
        'https://www.example.com/favicon-32.png',
        'https://www.example.com/favicon-16.png',
      ],
    );
  });

  test('解析 manifest 图标: 取尺寸最大的, 相对路径按 manifest 位置解析', () {
    const String json =
        '{"icons":[{"src":"/icons/64.png","sizes":"64x64"},'
        '{"src":"icons/512.png","sizes":"512x512"},'
        '{"src":"logo.svg","sizes":"any"}]}';
    expect(
      IconService.parseManifestIcons(
        json,
        Uri.parse('https://example.com/assets/site.webmanifest'),
      ),
      [
        'https://example.com/assets/icons/512.png',
        'https://example.com/icons/64.png',
      ],
    );
  });

  test('解析 manifest 地址与异常输入', () {
    expect(
      IconService.parseManifestUrl(
        '<link rel="manifest" href="/site.webmanifest">',
        Uri.parse('https://example.com/x'),
      ),
      'https://example.com/site.webmanifest',
    );
    expect(
      IconService.parseManifestUrl(
        '<html></html>',
        Uri.parse('https://example.com'),
      ),
      isNull,
    );
    expect(
      IconService.parseManifestIcons(
        'not json',
        Uri.parse('https://example.com'),
      ),
      isEmpty,
    );
    expect(
      IconService.parseManifestIcons(
        '{"icons":"oops"}',
        Uri.parse('https://example.com'),
      ),
      isEmpty,
    );
  });
}
