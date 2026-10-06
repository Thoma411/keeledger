/*
 * @Author: Thoma4
 * @Date: 2026-10-05 17:34:38
 * @LastEditTime: 2026-10-06 16:18:54
 * @Description: 新建账户页测试
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/pages/account_create_page.dart';

void main() {
  Widget wrap() =>
      const MaterialApp(home: AccountCreatePage(globalTags: {'金融'}));

  testWidgets('第1页展示必填字段与说明, 且不再全打星号', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('新建账户 (1/2)'), findsOneWidget);
    expect(find.text('平台名称（必填）'), findsOneWidget);
    expect(find.text('以下至少填写一项'), findsOneWidget);
    expect(find.text('用户昵称'), findsOneWidget);
    expect(find.text('登录账号'), findsOneWidget);
    expect(find.text('绑定邮箱'), findsOneWidget);
    expect(find.text('绑定手机'), findsOneWidget);
    expect(find.textContaining('*'), findsNothing);
    expect(find.text('下一步'), findsOneWidget);
  });

  testWidgets('缺平台名时点"下一步"停留在第1页并提示', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('下一步'));
    await tester.pump(); // 浮动提示

    expect(find.text('请填写平台名称'), findsOneWidget);
    expect(find.text('新建账户 (1/2)'), findsOneWidget); // 未跳页
  });
}
