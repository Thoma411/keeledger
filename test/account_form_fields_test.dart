/*
 * @Author: Thoma4
 * @Date: 2026-10-06 16:37:04
 * @LastEditTime: 2026-10-18 18:10:42
 * @Description: 共享表单字段部件测试(标签建议/日期并排)
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/models/preset.dart';
import 'package:keeledger/widgets/account_form_fields.dart';

void main() {
  // 采纳标签建议后应清空输入框
  testWidgets('采纳标签建议后输入框被清空', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _TagsHost(controller: controller)),
      ),
    );

    await tester.enterText(find.byType(TextField), '金');
    await tester.pump();
    expect(find.text('金融'), findsOneWidget); // 仅建议 chip
    // 建议 chip 与标签同款胶囊形
    expect(
      tester.widget<ActionChip>(find.byType(ActionChip)).shape,
      isA<StadiumBorder>(),
    );

    await tester.tap(find.text('金融'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(find.text('金融'), findsOneWidget); // 已变成标签 chip
  });

  // 新标签输入框要与已存在的标签 chip 等高
  // 用 compact 密度复刻桌面端: 密度会压缩输入框内容高度, 但 chip 不受影响
  for (final VisualDensity density in [
    VisualDensity.standard,
    VisualDensity.compact,
  ]) {
    testWidgets('标签输入框与标签 chip 等高(密度 $density)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(visualDensity: density),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AccountTagsRow(
                tags: const ['金融'],
                controller: controller,
                isEditing: true,
                globalTags: const {},
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final double chip = tester.getSize(find.byType(InputChip).first).height;
      final double input = tester.getSize(find.byType(TextField)).height;
      expect(input, chip, reason: '输入框($input)应与标签 chip($chip)等高');

      // 与 chip 同款胶囊: 全圆角描边
      final InputBorder? border = tester
          .widget<TextField>(find.byType(TextField))
          .decoration
          ?.border;
      expect(border, isA<OutlineInputBorder>());
      final OutlineInputBorder pill = border! as OutlineInputBorder;
      expect(pill.borderRadius.topLeft.x, greaterThanOrEqualTo(chip / 2));
      expect(
        pill.borderSide.color,
        Theme.of(
          tester.element(find.byType(TextField)),
        ).colorScheme.outlineVariant,
        reason: '描边色应与 chip 一致',
      );
    });
  }

  // 生日/注册日期: 常规字号并排, 字号过大时回落两行
  testWidgets('生日与注册日期常规字号并排, 大号字体回落两行', (tester) async {
    await tester.pumpWidget(_optionalApp(TextScaler.noScaling));
    expect(
      tester.getCenter(find.text('生日')).dy,
      tester.getCenter(find.text('注册日期')).dy,
    );

    await tester.pumpWidget(_optionalApp(const TextScaler.linear(1.5)));
    expect(
      tester.getCenter(find.text('生日')).dy,
      lessThan(tester.getCenter(find.text('注册日期')).dy),
    );
  });

  // 空字段出现 ▾ 快捷填入按钮时, 字段框不能变高
  // 用 0.85 倍字号复现: 文字行高变矮后, 36 的图标热区曾把空字段顶高
  testWidgets('空字段出现快捷填入按钮时字段框高度不变', (tester) async {
    Future<double> boxHeight({
      required bool emptyWithFill,
      required double textScale,
    }) async {
      final controller = TextEditingController(
        text: emptyWithFill ? '' : 'me@corp.com',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Column(
              children: [
                AccountFieldRow(
                  label: "绑定邮箱",
                  controller: controller,
                  isEditing: true,
                  presetKind: emptyWithFill ? PresetKind.email : null,
                  presets: emptyWithFill
                      ? [
                          Preset(
                            id: 'p1',
                            name: 'Gmail_1',
                            kind: PresetKind.email,
                            value: 'a@b.com',
                            lastModified: '2026-10-18T10:00:00',
                          ),
                        ]
                      : const [],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      // 真正绘制底色/边框的盒子(_InputBorderPainter 所在的 CustomPaint),
      // 它才是肉眼看到的"输入框高度"; 外层 InputDecorator 可能被其他约束撑大而不反映真实绘制
      for (final Element e
          in find
              .descendant(
                of: find.byType(InputDecorator).first,
                matching: find.byType(CustomPaint),
              )
              .evaluate()) {
        final RenderObject? ro = e.renderObject;
        if (ro is RenderBox && ro.hasSize && ro.size.width > 100) {
          return ro.size.height;
        }
      }
      return -1;
    }

    for (final double scale in [1.0, 0.85]) {
      final double withFill = await boxHeight(
        emptyWithFill: true,
        textScale: scale,
      );
      // 有候选时 ▾ 确实出现了
      expect(find.byType(IconButton), findsOneWidget);
      final double withoutFill = await boxHeight(
        emptyWithFill: false,
        textScale: scale,
      );
      expect(find.byType(IconButton), findsNothing);

      expect(
        withFill,
        withoutFill,
        reason: '字号 ${scale}x 时: 有 ▾ 的字段框不应更高($withFill vs $withoutFill)',
      );
    }
  });
}

// 可选字段页宿主(控制器统一在 tearDown 释放)
Widget _optionalApp(TextScaler scaler) {
  final url = TextEditingController();
  final tags = TextEditingController();
  final birth = TextEditingController();
  final signup = TextEditingController();
  final notes = TextEditingController();
  addTearDown(() {
    url.dispose();
    tags.dispose();
    birth.dispose();
    signup.dispose();
    notes.dispose();
  });

  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: AccountOptionalFields(
          url: url,
          tags: tags,
          birth: birth,
          signup: signup,
          notes: notes,
          tagList: const [],
          onTagsChanged: (_) {},
          globalTags: const {},
          status: 1,
          onStatusChanged: (_) {},
          realName: false,
          onRealNameChanged: (_) {},
        ),
      ),
    ),
  );
}

// 标签行宿主: 输入变化时重建(模拟页面里的 controller 监听)
class _TagsHost extends StatefulWidget {
  final TextEditingController controller;

  const _TagsHost({required this.controller});

  @override
  State<_TagsHost> createState() => _TagsHostState();
}

class _TagsHostState extends State<_TagsHost> {
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return AccountTagsRow(
      tags: _tags,
      controller: widget.controller,
      isEditing: true,
      globalTags: const {'金融', '社交'},
      onChanged: (list) => setState(() => _tags = list),
    );
  }
}
