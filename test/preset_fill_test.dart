/*
 * @Author: Thoma4
 * @Date: 2026-10-15 00:33:12
 * @LastEditTime: 2026-10-15 20:57:50
 * @Description: 字段级常用信息快捷填入测试
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keeledger/models/preset.dart';
import 'package:keeledger/widgets/account_form_fields.dart';

void main() {
  Preset preset(String id, String name, PresetKind kind, String value) =>
      Preset(
        id: id,
        name: name,
        kind: kind,
        value: value,
        lastModified: '2026-10-15T10:00:00',
      );

  // 录入样式(新增页/对话框)
  Widget formRow({
    required TextEditingController controller,
    required PresetKind kind,
    required List<Preset> presets,
    bool isPassword = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: isPassword
            ? AccountPasswordRow(
                controller: controller,
                isEditing: true,
                isVisible: false,
                onToggleVisible: () {},
                floatingLabel: true,
                presetKind: kind,
                presets: presets,
              )
            : AccountFieldRow(
                label: "字段",
                controller: controller,
                isEditing: true,
                floatingLabel: true,
                presetKind: kind,
                presets: presets,
              ),
      ),
    );
  }

  testWidgets('字段为空且有候选时展开胶囊, 点选后填入并收起', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      formRow(
        controller: controller,
        kind: PresetKind.email,
        presets: [
          preset('p1', 'Gmail_1', PresetKind.email, 'xxx1@gmail.com'),
          preset('p2', '公司邮箱', PresetKind.email, 'me@corp.com'),
        ],
      ),
    );

    // 空值 + 有候选 -> 出现入口
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    // 尚未展开
    expect(find.text('Gmail_1'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    expect(find.text('Gmail_1'), findsOneWidget);
    expect(find.text('公司邮箱'), findsOneWidget);

    await tester.tap(find.text('公司邮箱'));
    await tester.pump();
    expect(controller.text, 'me@corp.com');
    // 填入后字段非空 -> 入口消失, 胶囊收起
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.text('Gmail_1'), findsNothing);
  });

  testWidgets('字段已有内容时不提供入口', (tester) async {
    final controller = TextEditingController(text: '已填的内容');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      formRow(
        controller: controller,
        kind: PresetKind.email,
        presets: [preset('p1', 'Gmail_1', PresetKind.email, 'xxx1@gmail.com')],
      ),
    );

    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('没有候选(或类型不匹配)时不提供入口', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      formRow(
        controller: controller,
        kind: PresetKind.email,
        // 只有密码类型, 与邮箱字段不匹配
        presets: [preset('p1', '主密码', PresetKind.password, 'P@ssw0rd')],
      ),
    );

    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('密码行也能快捷填入, 且眼睛按钮仍在', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      formRow(
        controller: controller,
        kind: PresetKind.password,
        presets: [preset('p1', '主密码', PresetKind.password, 'P@ssw0rd')],
        isPassword: true,
      ),
    );

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget); // 眼睛未被挤掉

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    await tester.tap(find.text('主密码'));
    await tester.pump();

    expect(controller.text, 'P@ssw0rd');
  });

  testWidgets('只读态(非编辑)不提供入口', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountFieldRow(
            label: "绑定邮箱",
            controller: controller,
            isEditing: false,
            presetKind: PresetKind.email,
            presets: [
              preset('p1', 'Gmail_1', PresetKind.email, 'xxx1@gmail.com'),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('手机号填入时剔除非数字, 超过 11 位截断', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      formRow(
        controller: controller,
        kind: PresetKind.phone,
        presets: [preset('p1', '我的手机', PresetKind.phone, '138-0013-8000')],
      ),
    );

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    await tester.tap(find.text('我的手机'));
    await tester.pump();

    expect(controller.text, '13800138000');
  });

  testWidgets('手机号超过 11 位时截断(兜底)', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      formRow(
        controller: controller,
        kind: PresetKind.phone,
        presets: [preset('p1', '带区号', PresetKind.phone, '+8613800138000')],
      ),
    );

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    await tester.tap(find.text('带区号'));
    await tester.pump();

    expect(controller.text, '86138001380');
  });

  testWidgets('填入后光标停在末尾', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      formRow(
        controller: controller,
        kind: PresetKind.nickname,
        presets: [preset('p1', '我的昵称', PresetKind.nickname, '小明')],
      ),
    );

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    await tester.tap(find.text('我的昵称'));
    await tester.pump();

    expect(controller.selection.baseOffset, '小明'.length);
    expect(controller.selection.isCollapsed, isTrue);
  });
}
