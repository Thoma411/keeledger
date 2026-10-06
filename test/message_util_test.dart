/*
 * @Author: Thoma4
 * @Date: 2026-10-06 16:37:04
 * @LastEditTime: 2026-10-06 16:48:12
 * @Description: 悬浮胶囊提示测试(对话框场景需盖在遮罩之上)
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
}
