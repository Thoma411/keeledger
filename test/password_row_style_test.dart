/*
 * @Author: Thoma4
 * @Date: 2026-10-17 17:41:16
 * @LastEditTime: 2026-10-18 17:24:26
 * @Description: 详情页密码行样式测试
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keeledger/widgets/account_form_fields.dart';

void main() {
  // 详情页(只读样式)的密码行
  Widget detailPasswordRow({
    required TextEditingController controller,
    required bool isEditing,
    bool isVisible = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AccountPasswordRow(
          controller: controller,
          isEditing: isEditing,
          isVisible: isVisible,
          onToggleVisible: () {},
        ),
      ),
    );
  }

  testWidgets('编辑态: 使用样式B, 且眼睛图标在输入框内', (tester) async {
    final controller = TextEditingController(text: 'P@ssw0rd');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      detailPasswordRow(controller: controller, isEditing: true),
    );

    final InputDecoration decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(decoration.filled, isTrue); // 编辑态铺底色
    expect(decoration.border, InputBorder.none); // 无边框
    expect(decoration.focusedBorder, isA<UnderlineInputBorder>()); // 聚焦下划线
    expect(decoration.suffixIcon, isNotNull);

    // 图标是输入框的一部分, 不再与输入框并排
    expect(
      find.ancestor(
        of: find.byIcon(Icons.visibility_off),
        matching: find.byType(InputDecorator),
      ),
      findsOneWidget,
    );
    // 编辑态不显示复制按钮
    expect(find.byIcon(Icons.copy_all_rounded), findsNothing);

    // B 样式: 图标小一号(16), 热区 32(必须 ≤ 内容高度, 否则会顶高行)
    expect(tester.getSize(find.byType(IconButton)).height, 32);
    expect(tester.getSize(find.byIcon(Icons.visibility_off)).height, 16);
  });

  testWidgets('只读态: 掩码文案与眼睛/复制图标同在一个输入框内', (tester) async {
    final controller = TextEditingController(text: 'P@ssw0rd');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      detailPasswordRow(controller: controller, isEditing: false),
    );

    expect(find.byType(TextField), findsNothing); // 只读态不是输入框
    expect(find.text('••••••••'), findsOneWidget);
    expect(find.text('P@ssw0rd'), findsNothing);

    expect(
      find.ancestor(
        of: find.byIcon(Icons.visibility_off),
        matching: find.byType(InputDecorator),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byIcon(Icons.copy_all_rounded),
        matching: find.byType(InputDecorator),
      ),
      findsOneWidget,
    );

    final InputDecorator decorator = tester.widget<InputDecorator>(
      find.byType(InputDecorator),
    );
    expect(decorator.decoration.suffixIcon, isNotNull);
    expect(decorator.decoration.filled, isFalse); // 只读态不铺底色

    // 眼睛 + 复制两个图标并排且不溢出
    expect(find.byType(IconButton), findsNWidgets(2));
    expect(tester.getSize(find.byType(IconButton).at(0)).height, 32);
    expect(tester.getSize(find.byType(IconButton).at(1)).height, 32);

    // 顺序与编辑态/新建页对齐: 眼睛永远在最右
    final double copyX = tester
        .getCenter(find.byIcon(Icons.copy_all_rounded))
        .dx;
    final double eyeX = tester.getCenter(find.byIcon(Icons.visibility_off)).dx;
    expect(copyX, lessThan(eyeX), reason: '复制应在眼睛左侧');
  });
}
