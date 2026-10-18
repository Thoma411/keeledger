/*
 * @Author: Thoma4
 * @Date: 2026-10-18 21:49:24
 * @LastEditTime: 2026-10-18 22:01:41
 * @Description: 详情页回归测试(行高一致性 / 保存校验 / 密码行样式)
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:keeledger/models/account.dart';
import 'package:keeledger/services/auth_service.dart';
import 'package:keeledger/services/security_service.dart';
import 'package:keeledger/services/settings_service.dart';
import 'package:keeledger/services/storage_service.dart';
import 'package:keeledger/widgets/account_detail_view.dart';
import 'package:keeledger/widgets/account_form_fields.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('keeledger_detail_');
    StorageService.overrideDbPath = p.join(tempDir.path, 'test_vault.db');
    SharedPreferences.setMockInitialValues({});
    await SettingsService().init();
    SecurityService().clearKeys();
    await AuthService().createVault('password123');
  });

  tearDown(() async {
    await StorageService().closeDatabase();
    StorageService.overrideDbPath = null;
    SecurityService().clearKeys();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // 页面里的真实数据库IO只在真实异步区才能完成, 需要 runAsync 放行 + pumpAndSettle 排空
  Future<void> settleIo(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }
  }

  Account buildAccount({
    String notes = '单行备注',
    List<String> tags = const ['金融', '日常'],
  }) => Account(
    id: 'test-id',
    platform: 'AnchorPay',
    url: 'https://example.com',
    status: 1,
    tags: tags,
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

  Future<void> pumpDetail(
    WidgetTester tester,
    Account acc, {
    double textScale = 1.0,
  }) async {
    // 画布够大, 避免 SliverList 懒加载导致下部的行没被构建
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: AccountDetailView(
            key: UniqueKey(), // 强制重建, 避免复用上一次的编辑态状态
            account: acc,
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

  group('行高一致性', () {
    // 密码行已改为样式B(图标收进 suffixIcon), 与普通信息行一样参与等高断言
    const List<String> infoLabels = [
      '用户昵称',
      '用户ID',
      '绑定邮箱',
      '密码',
      '生日',
      '注册日期',
    ];

    // 字号会影响文字行高, 而行高 = max(文字行高 + padding, 图标热区),
    // 所以必须在小字号下也验证, 否则图标把行撑高的问题会被掩盖
    for (final double textScale in [1.0, 1.2, 0.85]) {
      testWidgets('编辑态各行高度一致(字号 ${textScale}x)', (tester) async {
        await pumpDetail(tester, buildAccount(), textScale: textScale);
        await tester.tap(find.text('编辑账户'));
        await tester.pumpAndSettle();

        final Map<String, double> heights = {
          for (final String l in infoLabels) l: rowHeight(tester, l),
        };

        expect(
          heights.values.toSet().length,
          1,
          reason: '字号 ${textScale}x 下各信息行高度应一致: $heights',
        );
      });
    }

    testWidgets('只读态与编辑态行高一致', (tester) async {
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

    testWidgets('备注行随内容增长, 超过 5 行封顶', (tester) async {
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
      expect(
        tenLines,
        closeTo(fiveLines, 1.0),
        reason: '超过 5 行应封顶在 5 行高度(框内滚动)',
      );
    });
  });

  group('保存校验', () {
    testWidgets('清空平台名称后保存被拦截', (tester) async {
      final account = buildAccount(tags: const ['金融']);
      await tester.runAsync(() => StorageService().insertAccount(account));

      await pumpDetail(tester, account);
      await settleIo(tester);

      await tester.tap(find.text("编辑账户"));
      await tester.pumpAndSettle();

      // 清空平台名称(标题区的第一个输入框)
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.pump();

      await tester.tap(find.text("保存修改"));
      await settleIo(tester);

      expect(find.text("平台名称不能为空。"), findsOneWidget); // 拦截提示
      expect(find.text("编辑账户"), findsNothing); // 仍停留在编辑态

      // 库里仍是原值
      final List<Account>? saved = await tester.runAsync(
        () => StorageService().getAllAccounts(),
      );
      expect(saved!.single.platform, 'AnchorPay');
    });
  });

  group('密码行样式', () {
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
      final double eyeX = tester
          .getCenter(find.byIcon(Icons.visibility_off))
          .dx;
      expect(copyX, lessThan(eyeX), reason: '复制应在眼睛左侧');
    });
  });
}
