/*
 * @Author: Thoma4
 * @Date: 2026-09-23 22:41:37
 * @LastEditTime: 2026-10-18 23:01:50
 * @Description: 图标仓库测试
 */

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/models/account.dart';
import 'package:keeledger/services/icon_store.dart';
import 'package:keeledger/services/storage_service.dart';
import 'helpers/vault_fixture.dart';

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
  useVaultFixture(
    tempPrefix: 'keeledger_icon_',
    dbFileName: 'icon_vault.db',
    createVault: false,
  );
  late Uint8List pngA, pngB, pngC;

  setUp(() async {
    await StorageService().database; // 触发建表
    IconStore().reset();
    pngA = await _png(16, 0xFF112233);
    pngB = await _png(24, 0xFF445566);
    pngC = await _png(32, 0xFF778899);
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
}
