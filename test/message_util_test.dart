/*
 * @Author: Thoma4
 * @Date: 2026-10-06 16:37:04
 * @LastEditTime: 2026-10-18 23:31:45
 * @Description: 悬浮胶囊提示测试(对话框场景需盖在遮罩之上且跟随键盘上移)
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/utils/utils.dart';

void main() {
  // 对话框内提示不能走 ScaffoldMessenger(会被遮罩盖住), 应插到 Overlay 顶层
  testWidgets('对话框内提示走 Overlay 而非 SnackBar', (tester) async {
    late BuildContext dialogContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (c) {
                  dialogContext = c;
                  return const AlertDialog(title: Text('弹窗'));
                },
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    MessageUtil.show(dialogContext, '提示文字');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // 淡入

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('提示文字'), findsOneWidget);

    // 走完停留与淡出, 确认能自行注销(不留悬挂定时器)
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('提示文字'), findsNothing);
  });

  // 模拟键盘唤起: 屏幕 400x800, 键盘高 300 -> 可用区域上沿 = 500
  void showKeyboard(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  }

  const double keyboardTop = 500;

  testWidgets('对话框内提示跟随键盘上移', (tester) async {
    showKeyboard(tester);
    late BuildContext dialogContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (c) {
                  dialogContext = c;
                  return const AlertDialog(title: Text('弹窗'));
                },
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    MessageUtil.show(dialogContext, '提示文字');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // 淡入

    expect(tester.getRect(find.text('提示文字')).bottom, lessThan(keyboardTop));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('普通页面提示跟随键盘上移', (tester) async {
    showKeyboard(tester);
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              return const TextField();
            },
          ),
        ),
      ),
    );

    MessageUtil.show(pageContext, '提示文字');
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.getRect(find.text('提示文字')).bottom, lessThan(keyboardTop));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
