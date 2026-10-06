/*
 * @Author: Thoma4
 * @Date: 2026-10-06 16:37:04
 * @LastEditTime: 2026-10-06 17:02:19
 * @Description: 共享表单字段部件测试(标签建议/日期并排)
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    await tester.tap(find.text('金融'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(find.text('金融'), findsOneWidget); // 已变成标签 chip
  });

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
