/*
 * @Author: Thoma4
 * @Date: 2026-09-23 22:41:37
 * @LastEditTime: 2026-09-23 23:24:17
 * @Description: 图标仓库测试
 */

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/models/account.dart';
import 'package:keeledger/services/icon_store.dart';
import 'package:keeledger/services/storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

// 生成指定尺寸的纯色PNG(低于上限, normalize 会原样返回)
Future<Uint8List> _png(int size, int color) async {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Uint8List pngA, pngB, pngC;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('keeledger_icon_');
    StorageService.overrideDbPath = p.join(tempDir.path, 'icon_vault.db');
    await StorageService().database; // 触发建表
    IconStore().reset();
    pngA = await _png(16, 0xFF112233);
    pngB = await _png(24, 0xFF445566);
    pngC = await _png(32, 0xFF778899);
  });

  tearDown(() async {
    await StorageService().closeDatabase();
    StorageService.overrideDbPath = null;
    IconStore().reset();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('指定图标后本账户命中, 同平台其他账户走平台名缓存', () async {
    final acc = _account(id: 'a1');
    await IconStore().setAccountIcon(acc, pngA);

    expect(IconStore().iconFor(acc), equals(pngA));
    expect(IconStore().iconFor(_account(id: 'a2')), equals(pngA));
  });

  test('解析优先级: 账户专属 > 域名缓存 > 平台名缓存', () async {
    final acc = _account(id: 'a1', url: 'https://www.example.com/login');
    final noUrl = _account(id: 'a2');
    final otherDomain = _account(id: 'a3', url: 'https://other.com');

    await IconStore().putCache(IconStore.domainKey(acc.url), pngA);
    expect(IconStore().iconFor(acc), equals(pngA));
    expect(IconStore().iconFor(noUrl), isNull); // 平台名缓存还是空的

    await IconStore().putCache(IconStore.platformKey('GitHub'), pngB);
    expect(IconStore().iconFor(acc), equals(pngA)); // 域名缓存优先
    expect(IconStore().iconFor(noUrl), equals(pngB));
    expect(IconStore().iconFor(otherDomain), equals(pngB));

    await IconStore().setAccountIcon(acc, pngC);
    expect(IconStore().iconFor(acc), equals(pngC)); // 专属图标优先
  });

  test('清缓存只清共享缓存, 账户专属图标保留', () async {
    final acc = _account(id: 'a1', url: 'https://example.com');
    await IconStore().setAccountIcon(acc, pngA);
    await IconStore().putCache(IconStore.domainKey(acc.url), pngB);

    await IconStore().clearCache();

    expect(IconStore().iconFor(acc), equals(pngA));
    expect(IconStore().iconFor(_account(id: 'a2')), isNull);
  });

  test('删除账户后其专属图标被清理(共享缓存不受影响)', () async {
    final acc = _account(id: 'a1');
    await IconStore().setAccountIcon(acc, pngA);
    await IconStore().clearCache(); // 先清掉平台名缓存便于观察

    await IconStore().removeAccountIcon(acc.id);

    expect(IconStore().iconFor(acc), isNull);
    expect(IconStore().iconFor(_account(id: 'a2')), isNull);
  });

  test('重新 load 可从数据库恢复(入库持久化)', () async {
    final acc = _account(id: 'a1');
    await IconStore().setAccountIcon(acc, pngA);
    await IconStore().putCache(
      IconStore.domainKey('https://example.com'),
      pngB,
    );

    IconStore().reset();
    expect(IconStore().iconFor(acc), isNull);

    await IconStore().load();

    expect(IconStore().iconFor(acc), equals(pngA));
    expect(
      IconStore().iconFor(_account(id: 'x', url: 'https://example.com')),
      equals(pngB),
    );
  });

  test('缓存键规范化', () {
    expect(
      IconStore.domainKey('https://www.Example.com/login'),
      'domain:example.com',
    );
    expect(IconStore.domainKey('example.com'), 'domain:example.com');
    expect(IconStore.domainKey(''), '');
    expect(IconStore.platformKey('GitHub_2'), 'name:github');
    expect(IconStore.platformKey('GitHub（3）'), 'name:github');
    expect(IconStore.platformKey('微博 副本'), 'name:微博');
    expect(IconStore.platformKey('微博'), 'name:微博');
  });
}
