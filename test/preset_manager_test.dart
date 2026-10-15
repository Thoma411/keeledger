/*
 * @Author: Thoma4
 * @Date: 2026-10-13 22:52:20
 * @LastEditTime: 2026-10-15 23:39:30
 * @Description: 常用信息管理页测试
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:keeledger/models/preset.dart';
import 'package:keeledger/pages/preset_manager_page.dart';
import 'package:keeledger/services/auth_service.dart';
import 'package:keeledger/services/security_service.dart';
import 'package:keeledger/services/settings_service.dart';
import 'package:keeledger/services/storage_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('keeledger_preset_ui_');
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
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // 页面 initState 里的真实数据库IO只在真实异步区才能完成
  // 测试体默认跑在 FakeAsync 中: 真实数据库IO要靠 runAsync 放行,
  // 而每个 await 的续体还要靠 pumpAndSettle 排空微任务。
  // 一条链路可能要跨 6~8 段IO(查存在/删除/推修订号/重读/查询), 故留足轮数。
  Future<void> settleIo(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }
  }

  // 造数据同样不能留在 FakeAsync 里
  Future<void> seed(
    WidgetTester tester,
    String id,
    String name,
    PresetKind kind,
    String value,
  ) async {
    await tester.runAsync(
      () => StorageService().savePreset(
        Preset(
          id: id,
          name: name,
          kind: kind,
          value: value,
          lastModified: '2026-10-13T10:00:00',
        ),
      ),
    );
  }

  Widget app() => const MaterialApp(home: PresetManagerPage());

  testWidgets('空库展示空态引导', (tester) async {
    await tester.pumpWidget(app());
    await settleIo(tester);

    expect(find.text('新建常用信息'), findsOneWidget);
    expect(find.text("仅用于快捷填入账户字段，点击右上角'+'号新建"), findsOneWidget);
  });

  testWidgets('列表展示条目, 密码默认掩码', (tester) async {
    await seed(tester, 'p1', 'Gmail_1', PresetKind.email, 'xxx1@gmail.com');
    await seed(tester, 'p2', '主密码', PresetKind.password, 'P@ssw0rd');

    await tester.pumpWidget(app());
    await settleIo(tester);

    expect(find.text('Gmail_1'), findsOneWidget);
    expect(find.text('xxx1@gmail.com'), findsOneWidget);
    expect(find.text('主密码'), findsOneWidget);
    expect(find.text('••••••'), findsOneWidget);
    expect(find.text('P@ssw0rd'), findsNothing); // 密码默认不显示
  });

  testWidgets('单击密码条目可显示/隐藏明文', (tester) async {
    await seed(tester, 'p1', '主密码', PresetKind.password, 'P@ssw0rd');

    await tester.pumpWidget(app());
    await settleIo(tester);

    await tester.tap(find.text('主密码'));
    await tester.pump();
    expect(find.text('P@ssw0rd'), findsOneWidget);

    await tester.tap(find.text('主密码'));
    await tester.pump();
    expect(find.text('P@ssw0rd'), findsNothing);
  });

  testWidgets('复制按钮写入剪贴板, 密码复制的是明文', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await seed(tester, 'p1', '主密码', PresetKind.password, 'P@ssw0rd');

    await tester.pumpWidget(app());
    await settleIo(tester);

    await tester.tap(find.byTooltip('复制'));
    await tester.pump();

    expect(calls, hasLength(1));
    expect((calls.first.arguments as Map)['text'], 'P@ssw0rd');
  });

  testWidgets('删除需二次确认, 确认后条目消失', (tester) async {
    await seed(tester, 'p1', 'Gmail_1', PresetKind.email, 'xxx1@gmail.com');

    await tester.pumpWidget(app());
    await settleIo(tester);
    expect(find.text('Gmail_1'), findsOneWidget);

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(find.text('已填入账户中的内容不受影响。'), findsOneWidget);

    await tester.tap(find.text('删除')); // 确认框中的危险按钮
    await tester.pump();
    await settleIo(tester);

    expect(find.text('已填入账户中的内容不受影响。'), findsNothing); // 确认框已关闭
    expect(find.text('Gmail_1'), findsNothing);
    expect(find.text('新建常用信息'), findsOneWidget);
  });

  testWidgets('新建弹层: 名称为空时提示且不落库', (tester) async {
    await tester.pumpWidget(app());
    await settleIo(tester);

    await tester.tap(find.byTooltip('新建'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('请填写名称'), findsOneWidget);

    // 走完悬浮提示的停留与淡出, 避免残留定时器
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('新建: 未选类型时提示', (tester) async {
    await tester.pumpWidget(app());
    await settleIo(tester);

    await tester.tap(find.byTooltip('新建'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Gmail_1');
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('请选择类型'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('新建弹层: 仅选中密码类型时给出红字提醒', (tester) async {
    const String warning = "尽管应用允许将密码添加为常用信息，但仍不建议这么做。";

    await tester.pumpWidget(app());
    await settleIo(tester);

    await tester.tap(find.byTooltip('新建'));
    await tester.pumpAndSettle();
    expect(find.text(warning), findsNothing); // 默认不显示

    await tester.tap(find.byType(DropdownButtonFormField<PresetKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('密码').last);
    await tester.pumpAndSettle();

    expect(find.text(warning), findsOneWidget);
  });

  // 手机类型的公共步骤: 填名称 -> 选手机 -> 填内容
  Future<void> fillPhoneForm(WidgetTester tester, String value) async {
    await tester.pumpWidget(app());
    await settleIo(tester);

    await tester.tap(find.byTooltip('新建'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '我的手机');
    await tester.tap(find.byType(DropdownButtonFormField<PresetKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('绑定手机').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, value);
  }

  testWidgets('新建弹层: 手机类型会展示格式说明', (tester) async {
    await fillPhoneForm(tester, '13800138000');

    expect(find.text('一个合法的手机号应当仅包含数字，且不超过 11 位。'), findsOneWidget);
  });

  testWidgets('新建弹层: 手机号超过 11 位时阻止保存', (tester) async {
    await fillPhoneForm(tester, '8613800138000'); // 13 位纯数字(带区号)

    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('输入不合法'), findsOneWidget);

    // 走完悬浮提示的停留与淡出, 避免残留定时器
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('新建弹层: 手机号含非法字符时阻止保存(即使不超过 11 位)', (tester) async {
    await fillPhoneForm(tester, '138abc00123'); // 11 位但含字母

    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('输入不合法'), findsOneWidget);

    // 走完悬浮提示的停留与淡出, 避免残留定时器
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('新建弹层: 手机号 11 位数字可保存, 且去除首尾空格', (tester) async {
    await fillPhoneForm(tester, '  13800138000  ');

    await tester.tap(find.text('保存'));
    await tester.pump();
    await settleIo(tester);

    expect(find.text('13800138000'), findsOneWidget); // 列表里不带空格
  });

  testWidgets('每类数量上限: 已满的类型在下拉里标记已满且不可选', (tester) async {
    for (int i = 0; i < Preset.maxPerKind; i++) {
      await seed(tester, 'e$i', '邮箱$i', PresetKind.email, 'a$i@b.com');
    }

    await tester.pumpWidget(app());
    await settleIo(tester);

    await tester.tap(find.byTooltip('新建'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<PresetKind>));
    await tester.pumpAndSettle();

    expect(find.text('绑定邮箱（已满）'), findsOneWidget);

    final List<DropdownMenuItem<PresetKind>> items = tester
        .widgetList<DropdownMenuItem<PresetKind>>(
          find.byType(DropdownMenuItem<PresetKind>),
        )
        .toList();
    expect(items, hasLength(PresetKind.values.length));
    expect(
      items.firstWhere((i) => i.value == PresetKind.email).enabled,
      isFalse,
    );
    expect(
      items.firstWhere((i) => i.value == PresetKind.phone).enabled,
      isTrue,
    );
  });

  testWidgets('每类数量上限: 所有类型都满时不再打开新建弹层', (tester) async {
    for (final PresetKind kind in PresetKind.values) {
      for (int i = 0; i < Preset.maxPerKind; i++) {
        await seed(tester, '${kind.code}$i', '${kind.label}$i', kind, 'v$i');
      }
    }

    await tester.pumpWidget(app());
    await settleIo(tester);

    await tester.tap(find.byTooltip('新建'));
    await tester.pumpAndSettle();

    expect(find.text('新建常用信息'), findsNothing); // 弹层没被打开
    expect(find.text('已达条数上限'), findsOneWidget);

    // 走完提示的停留, 避免残留定时器
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
