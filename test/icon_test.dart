/*
 * @Author: Thoma4
 * @Date: 2026-10-18 23:06:02
 * @LastEditTime: 2026-10-18 23:13:55
 * @Description: 图标子系统测试(编解码缩放 / 仓库读写 / 地址抓取解析)
 */

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keeledger/models/account.dart';
import 'package:keeledger/services/icon_service.dart';
import 'package:keeledger/services/icon_store.dart';
import 'package:keeledger/services/storage_service.dart';
import 'package:keeledger/utils/icon_codec.dart';
import 'helpers/vault_fixture.dart';

// 生成指定尺寸的纯色PNG
Future<Uint8List> _pngSized(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFF3366FF),
  );
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

// 生成指定尺寸的纯色PNG(低于上限, normalize 会原样返回)
Future<Uint8List> _pngSolid(int size, int color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = Color(color),
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

Account _account({
  required String id,
  String platform = 'GitHub',
  String url = '',
}) => Account(
  id: id,
  platform: platform,
  url: url,
  status: 1,
  name: '昵称',
  userId: 'user',
  email: 'a@b.com',
  pswd: 'pwd',
  phone: '13800000000',
  realName: false,
  lastModified: '2026-09-23 10:00:00',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('编解码缩放', () {
    test('超过上限的图标等比缩到 256px', () async {
      final out = await IconCodec.normalize(await _pngSized(512, 512));
      final image = await _decode(out);
      expect(image.width, 256);
      expect(image.height, 256);
      image.dispose();
    });

    test('非正方形图标按长边缩放', () async {
      final out = await IconCodec.normalize(await _pngSized(600, 300));
      final image = await _decode(out);
      expect(image.width, 256);
      expect(image.height, 128);
      image.dispose();
    });

    test('未超过上限的图标原样返回', () async {
      final raw = await _pngSized(128, 96);
      expect(identical(await IconCodec.normalize(raw), raw), isTrue);
    });
  });

  group('仓库读写', () {
    useVaultFixture(
      tempPrefix: 'keeledger_icon_',
      dbFileName: 'icon_vault.db',
      createVault: false,
    );
    late Uint8List pngA, pngB, pngC;

    setUp(() async {
      await StorageService().database; // 触发建表
      IconStore().reset();
      pngA = await _pngSolid(16, 0xFF112233);
      pngB = await _pngSolid(24, 0xFF445566);
      pngC = await _pngSolid(32, 0xFF778899);
    });

    tearDown(() async {
      IconStore().reset();
    });

    test('指定图标后仅该账户命中', () async {
      final acc = _account(id: 'a1');
      await IconStore().setAccountIcon(acc, pngA);

      expect(IconStore().iconFor(acc), equals(pngA));
      expect(IconStore().iconFor(_account(id: 'a2')), isNull);
    });

    test('解析优先级: 账户专属 > 域名缓存', () async {
      final acc = _account(id: 'a1', url: 'https://www.example.com/login');
      final sameDomain = _account(id: 'a2', url: 'https://example.com/home');
      final otherDomain = _account(id: 'a3', url: 'https://other.com');

      await IconStore().putCache(IconStore.domainKey(acc.url), pngA);
      expect(IconStore().iconFor(acc), equals(pngA));
      expect(IconStore().iconFor(sameDomain), equals(pngA)); // 缓存按域名共享
      expect(IconStore().iconFor(otherDomain), isNull);

      await IconStore().setAccountIcon(acc, pngB);
      expect(IconStore().iconFor(acc), equals(pngB)); // 专属图标优先
      expect(IconStore().iconFor(sameDomain), equals(pngA)); // 同域其他账户不受影响
    });

    test('清缓存只清共享缓存, 账户专属图标保留', () async {
      final acc = _account(id: 'a1', url: 'https://example.com');
      await IconStore().setAccountIcon(acc, pngA);
      await IconStore().putCache(IconStore.domainKey(acc.url), pngB);

      await IconStore().clearCache();

      expect(IconStore().iconFor(acc), equals(pngA));
      expect(IconStore().iconFor(_account(id: 'a2')), isNull);
    });

    test('删除账户专属图标后回落到域名缓存', () async {
      final acc = _account(id: 'a1', url: 'https://example.com');
      await IconStore().setAccountIcon(acc, pngA);
      await IconStore().putCache(IconStore.domainKey(acc.url), pngB);
      expect(IconStore().iconFor(acc), equals(pngA));

      await IconStore().removeAccountIcon(acc.id);

      expect(IconStore().iconFor(acc), equals(pngB));
    });

    test('重新 load 可从数据库恢复(入库持久化)', () async {
      final acc = _account(id: 'a1');
      await IconStore().setAccountIcon(acc, pngA);
      await IconStore().putCache(
        IconStore.domainKey('https://example.com'),
        pngC,
      );

      IconStore().reset();
      expect(IconStore().iconFor(acc), isNull);

      await IconStore().load();

      expect(IconStore().iconFor(acc), equals(pngA));
      expect(
        IconStore().iconFor(_account(id: 'x', url: 'https://example.com')),
        equals(pngC),
      );
    });

    test('域名键规范化', () {
      expect(
        IconStore.domainKey('https://www.Example.com/login'),
        'domain:example.com',
      );
      expect(IconStore.domainKey('example.com'), 'domain:example.com');
      expect(IconStore.domainKey(''), '');
    });
  });

  group('地址抓取解析', () {
    test('自定义图标源: 必须含 {domain} 才生效', () {
      expect(
        IconService.customSourceUrl(
          'https://my.icon/{domain}.png',
          'github.com',
        ),
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
          'https://example.com/assets/64.png', // 根绝对路径的"同目录"变体
        ],
      );
    });

    test('相对路径按文档最终地址解析(如 301 到 /index/)', () {
      expect(
        IconService.parseHtmlIcons(
          '<link rel="shortcut icon" href="images/favicon.ico" type="image/x-icon">',
          Uri.parse('https://www.12306.cn/index/'),
        ),
        ['https://www.12306.cn/index/images/favicon.ico'],
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
  });
}
