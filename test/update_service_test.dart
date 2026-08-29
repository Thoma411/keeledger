/*
 * @Author: Thoma4
 * @Date: 2026-08-29 17:46:49
 * @LastEditTime: 2026-08-29 18:06:16
 * @Description: 获取release新版本测试
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/services/update_service.dart';

void main() {
  group('parseVersion', () {
    test('解析标准版本号', () {
      expect(UpdateService.parseVersion('v1.2.3'), [1, 2, 3]);
      expect(UpdateService.parseVersion('1.10.0'), [1, 10, 0]);
      expect(UpdateService.parseVersion('v0.9.0-beta.1'), [0, 9, 0]);
      expect(UpdateService.parseVersion('  v1.2.3  '), [1, 2, 3]);
    });

    test('无法解析时返回 null', () {
      expect(UpdateService.parseVersion('abc'), isNull);
      expect(UpdateService.parseVersion(''), isNull);
      expect(UpdateService.parseVersion('version'), isNull);
    });
  });

  group('isNewer', () {
    test('高于/低于/相等判断', () {
      expect(UpdateService.isNewer('v1.1.1', 'v1.0.0'), isTrue);
      expect(UpdateService.isNewer('v1.0.0', 'v1.1.1'), isFalse);
      expect(UpdateService.isNewer('v1.1.1', 'v1.1.1'), isFalse);
    });

    test('次版本优先于补丁版本', () {
      expect(UpdateService.isNewer('v1.2.0', 'v1.1.9'), isTrue);
      expect(UpdateService.isNewer('v1.1.9', 'v1.2.0'), isFalse);
    });

    test('含无法解析的版本时不误判', () {
      expect(UpdateService.isNewer('abc', 'v1.1.1'), isFalse);
      expect(UpdateService.isNewer('v1.1.1', 'abc'), isFalse);
    });
  });

  group('pickLatest', () {
    Map<String, dynamic> release(String tag) => {
      'tag_name': tag,
      'html_url': 'https://github.com/Thoma411/keeledger/releases/tag/$tag',
      'body': '说明',
      'assets': <Map<String, dynamic>>[
        {
          'name': 'keeledger-arm64-v8a-release.apk',
          'browser_download_url':
              'https://github.com/Thoma411/keeledger/releases/download/$tag/keeledger-arm64-v8a-release.apk',
        },
      ],
    };

    test('乱序发布中选出版本号最高者', () {
      final releases = [
        release('v1.1.0'),
        release('v1.1.1'),
        release('v1.0.0'),
      ];
      final latest = UpdateService.pickLatest(releases);
      expect(latest, isNotNull);
      expect(latest!['tag_name'], 'v1.1.1');
    });

    test('首位旧版不误选(回归: releases.first 隐患)', () {
      final releases = [release('v1.0.0'), release('v1.1.1')];
      final latest = UpdateService.pickLatest(releases);
      expect(latest, isNotNull);
      expect(latest!['tag_name'], 'v1.1.1');
    });

    test('无法解析的条目被跳过', () {
      final releases = [
        release('v1.0.0'),
        {'tag_name': 'not-a-version', 'html_url': '', 'body': '', 'assets': []},
      ];
      final latest = UpdateService.pickLatest(releases);
      expect(latest, isNotNull);
      expect(latest!['tag_name'], 'v1.0.0');
    });

    test('空列表或无有效版本返回 null', () {
      expect(UpdateService.pickLatest([]), isNull);
      expect(
        UpdateService.pickLatest([
          {'tag_name': 'abc'},
        ]),
        isNull,
      );
    });
  });
}
