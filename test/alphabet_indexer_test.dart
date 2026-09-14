/*
 * @Author: Thoma4
 * @Date: 2026-09-14 21:27:57
 * @LastEditTime: 2026-09-14 22:20:05
 * @Description: 字母索引组件测试
 */

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/widgets/alphabet_indexer.dart';

void main() {
  const Map<String, int> indexMap = {'#': 0, 'A': 1, 'C': 3, 'Z': 26};
  const double padding = 8; // 索引条上下内边距

  // 构建固定高度的索引条并返回其屏幕矩形
  Future<Rect> pumpIndexer(WidgetTester tester, List<String> selected) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 540,
              child: AlphabetIndexer(
                alphabetIndexMap: indexMap,
                onLetterSelected: selected.add,
              ),
            ),
          ),
        ),
      ),
    );
    return tester.getRect(find.byType(AlphabetIndexer));
  }

  // 第 index 个字母中心的屏幕纵坐标
  double letterY(Rect box, int index) =>
      box.top + padding + (box.height - padding * 2) / 27 * (index + 0.5);

  testWidgets('按住滑动可连续切换首字母, 无数据与重复字母不触发', (tester) async {
    final selected = <String>[];
    final Rect box = await pumpIndexer(tester, selected);

    // 按下 '#'
    final gesture = await tester.startGesture(
      Offset(box.center.dx, letterY(box, 0)),
    );
    expect(selected, ['#']);

    // 滑到 'A'
    await gesture.moveTo(Offset(box.center.dx, letterY(box, 1)));
    expect(selected, ['#', 'A']);

    // 滑过无数据的 'B' 不触发
    await gesture.moveTo(Offset(box.center.dx, letterY(box, 2)));
    expect(selected, ['#', 'A']);

    // 滑到 'C'
    await gesture.moveTo(Offset(box.center.dx, letterY(box, 3)));
    expect(selected, ['#', 'A', 'C']);

    // 同一字母内轻微抖动不重复触发
    await gesture.moveTo(Offset(box.center.dx + 3, letterY(box, 3) + 2));
    expect(selected, ['#', 'A', 'C']);

    // 滑出上方/下方时钳制到首/末字母
    await gesture.moveTo(Offset(box.center.dx, box.top - 80));
    expect(selected, ['#', 'A', 'C', '#']);
    await gesture.moveTo(Offset(box.center.dx, box.bottom + 80));
    expect(selected, ['#', 'A', 'C', '#', 'Z']);

    await gesture.up();
  });

  testWidgets('松开后点击同一字母可再次触发', (tester) async {
    final selected = <String>[];
    final Rect box = await pumpIndexer(tester, selected);

    await tester.tapAt(Offset(box.center.dx, letterY(box, 1)));
    expect(selected, ['A']);
    await tester.tapAt(Offset(box.center.dx, letterY(box, 1)));
    expect(selected, ['A', 'A']);
  });

  testWidgets('按住时中央显示当前字母气泡, 滑动跟随, 松开消失', (tester) async {
    final selected = <String>[];
    final Rect box = await pumpIndexer(tester, selected);
    final bubble = find.byKey(const Key('alphabetIndexerBubble'));

    expect(bubble, findsNothing); // 未按下时无气泡

    // 按住 'A'
    final gesture = await tester.startGesture(
      Offset(box.center.dx, letterY(box, 1)),
    );
    await tester.pump();
    expect(bubble, findsOneWidget);
    expect(tester.widget<Text>(bubble).data, 'A');

    // 滑到 'C', 气泡跟随
    await gesture.moveTo(Offset(box.center.dx, letterY(box, 3)));
    await tester.pump();
    expect(tester.widget<Text>(bubble).data, 'C');

    // 滑过无数据的 'B': 气泡仍提示字母, 但不触发跳转
    await gesture.moveTo(Offset(box.center.dx, letterY(box, 2)));
    await tester.pump();
    expect(tester.widget<Text>(bubble).data, 'B');

    // 松开后气泡消失
    await gesture.up();
    await tester.pump();
    expect(bubble, findsNothing);
    expect(selected, ['A', 'C']);
  });

  testWidgets('按下时当前字母有底色强调, 滑动跟随, 松开消失', (tester) async {
    final selected = <String>[];
    final Rect box = await pumpIndexer(tester, selected);
    final active = find.byKey(const Key('alphabetIndexerActive'));
    final activeText = find.descendant(of: active, matching: find.byType(Text));

    expect(active, findsNothing);

    final gesture = await tester.startGesture(
      Offset(box.center.dx, letterY(box, 1)),
    );
    await tester.pump();
    expect(active, findsOneWidget);
    expect(tester.widget<Text>(activeText).data, 'A');

    // 滑到 'C' 强调跟随移动
    await gesture.moveTo(Offset(box.center.dx, letterY(box, 3)));
    await tester.pump();
    expect(tester.widget<Text>(activeText).data, 'C');

    await gesture.up();
    await tester.pump();
    expect(active, findsNothing);
  });

  testWidgets('气泡字母为单线主题色下划线, 不再继承错误样式', (tester) async {
    final selected = <String>[];
    final Rect box = await pumpIndexer(tester, selected);

    final gesture = await tester.startGesture(
      Offset(box.center.dx, letterY(box, 1)),
    );
    await tester.pump();

    // 取实际参与渲染的合并样式(RenderParagraph上的最终TextStyle)
    final RenderParagraph para = tester.renderObject<RenderParagraph>(
      find.byKey(const Key('alphabetIndexerBubble')),
    );
    final TextStyle? style = para.text.style;
    expect(style?.decoration, TextDecoration.underline);
    expect(style?.decorationStyle, TextDecorationStyle.solid); // 非double
    expect(style?.fontFamily, isNot('monospace')); // 不再等宽
    expect(style?.decorationColor, isNotNull);
    expect(
      style?.decorationColor,
      isNot(const Color(0xFFFFFF00)), // 非错误样式的黄色
    );

    await gesture.up();
    await tester.pump();
  });
}
