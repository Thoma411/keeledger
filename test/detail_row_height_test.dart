/*
 * @Author: Thoma4
 * @Date: 2026-09-18 23:52:02
 * @LastEditTime: 2026-09-19 00:19:44
 * @Description: 详情页信息行高度一致性回归测试
 */

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keeledger/models/account.dart';
import 'package:keeledger/widgets/account_detail_view.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('keeledger_detail_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Account buildAccount({String notes = '单行备注'}) => Account(
    id: 'test-id',
    platform: 'AnchorPay',
    url: 'https://example.com',
    status: 1,
    tags: const ['金融', '日常'],
    name: '张三',
    userId: 'anchor_001',
    email: 'zhangsan@example.com',
    pswd: 'P@ssw0rd123',
    phone: '13800000000',
    birth: DateTime(1990, 1, 1),
    notes: notes,
    signupDate: DateTime(2020, 5, 1),
    realName: true,
    favorite: false,
    lastModified: '2026-09-18T00:00:00.000Z',
  );

  Future<void> pumpDetail(WidgetTester tester, Account acc) async {
    // 画布够大, 避免 SliverList 懒加载导致下部的行没被构建
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountDetailView(
            key: UniqueKey(), // 强制重建, 避免复用上一次的编辑态状态
            account: acc,
            iconDirPath: tempDir.path,
            globalTags: const {'金融', '日常'},
            onClose: () {},
            onSaveSuccess: () {},
            onDeleteSuccess: () {},
            onTagClicked: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // 信息行的行高 = 标签 + 间隔 + 值/输入框
  double rowHeight(WidgetTester tester, String label) {
    final Finder row = find.ancestor(
      of: find.text(label),
      matching: find.byType(Column),
    );
    expect(
      row.evaluate(),
      isNotEmpty,
      reason:
          '未找到行 "$label"; 当前文本: '
          '${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
    );
    return tester.getSize(row.first).height;
  }

  // 密码行不参与"各行等高"断言: 其右侧显示/复制按钮是标准尺寸 IconButton(点击区 48),
  // 行高会高于普通信息行(但它自身在只读/编辑两态间是一致的, 见下个用例)
  const List<String> infoLabels = ['用户昵称', '登录账号', '绑定邮箱', '生日', '注册日期'];

  testWidgets('详情页: 编辑态各行高度一致(含日期行)', (tester) async {
    await pumpDetail(tester, buildAccount());
    await tester.tap(find.text('编辑账户'));
    await tester.pumpAndSettle();

    final Map<String, double> heights = {
      for (final String l in infoLabels) l: rowHeight(tester, l),
    };

    expect(
      heights.values.toSet().length,
      1,
      reason: '各信息行高度应一致(日期行不应更高): $heights',
    );
  });

  testWidgets('详情页: 只读态与编辑态行高一致', (tester) async {
    await pumpDetail(tester, buildAccount());
    final Map<String, double> readOnly = {
      for (final String l in ['用户昵称', '密码']) l: rowHeight(tester, l),
    };

    await tester.tap(find.text('编辑账户'));
    await tester.pumpAndSettle();

    for (final String l in readOnly.keys) {
      expect(
        rowHeight(tester, l),
        closeTo(readOnly[l]!, 1.0),
        reason: '"$l"行切换编辑态不应改变行高',
      );
    }
  });

  testWidgets('详情页: 备注行随内容增长, 超过 5 行封顶', (tester) async {
    Future<double> notesRowHeight(String notes) async {
      await pumpDetail(tester, buildAccount(notes: notes));
      await tester.tap(find.text('编辑账户'));
      await tester.pumpAndSettle();
      return rowHeight(tester, '备注');
    }

    final double oneLine = await notesRowHeight('一行');
    final double threeLines = await notesRowHeight('一\n二\n三');
    final double fiveLines = await notesRowHeight('一\n二\n三\n四\n五');
    final double tenLines = await notesRowHeight(
      '一\n二\n三\n四\n五\n六\n七\n八\n九\n十',
    );

    expect(threeLines, greaterThan(oneLine));
    expect(fiveLines, greaterThan(threeLines));
    expect(tenLines, closeTo(fiveLines, 1.0), reason: '超过 5 行应封顶在 5 行高度(框内滚动)');
  });
}
