/*
 * @Author: Thoma4
 * @Date: 2026-09-20 21:22:26
 * @LastEditTime: 2026-09-20 22:26:38
 * @Description: 数据落点(便携判定)测试
 */

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:keeledger/utils/app_paths.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('keeledger_paths_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('注入根目录时按注入值确定落点并建目录', () async {
    AppPaths.overrideRoot = p.join(tempDir.path, 'data');
    AppPaths.overridePortable = true;
    addTearDown(() {
      AppPaths.overrideRoot = null;
      AppPaths.overridePortable = null;
    });

    await AppPaths.init();

    expect(AppPaths.isInitialized, isTrue);
    expect(AppPaths.isPortable, isTrue);
    expect(Directory(AppPaths.root).existsSync(), isTrue);
    expect(AppPaths.settingsFile, p.join(AppPaths.root, 'settings.json'));
  });

  test('历史库一次性平移(含 wal/shm)', () async {
    final String from = p.join(tempDir.path, 'old', 'keeledger.db');
    final String to = p.join(tempDir.path, 'data', 'keeledger.db');
    await Directory(p.dirname(from)).create(recursive: true);
    await Directory(p.dirname(to)).create(recursive: true);
    await File(from).writeAsString('main');
    await File('$from-wal').writeAsString('wal');
    await File('$from-shm').writeAsString('shm');

    expect(await AppPaths.adoptLegacyDb(from, to), isTrue);
    expect(File(to).readAsStringSync(), 'main');
    expect(File('$to-wal').existsSync(), isTrue);
    expect(File('$to-shm').existsSync(), isTrue);
    expect(File(from).existsSync(), isFalse);

    // 目标已存在 → 不覆盖
    await File(from).writeAsString('again');
    expect(await AppPaths.adoptLegacyDb(from, to), isFalse);
    expect(File(to).readAsStringSync(), 'main');
  });
}
