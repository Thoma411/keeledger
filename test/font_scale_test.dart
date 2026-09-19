/*
 * @Author: Thoma4
 * @Date: 2026-09-19 15:01:15
 * @LastEditTime: 2026-09-19 15:32:46
 * @Description: 字号档位与固定尺寸缩放测试
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keeledger/utils/utils.dart';
import 'package:keeledger/widgets/account_ui_utils.dart';

void main() {
  test('字号档位 -> 应用内倍率', () {
    expect(FontScaleUtil.toScale('large'), FontScaleUtil.large);
    expect(FontScaleUtil.toScale('normal'), FontScaleUtil.normal);
    expect(FontScaleUtil.toScale('unknown'), FontScaleUtil.normal);
  });

  testWidgets('固定尺寸随文字缩放等比放大, 且封顶 1.6 倍', (tester) async {
    Future<double> scaledAt(double textScale) async {
      late double result;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Builder(
              builder: (context) {
                result = AccountUiUtils.scaledFixed(context, 68);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return result;
    }

    expect(await scaledAt(1.0), 68); // 标准档不变
    expect(await scaledAt(1.2), closeTo(81.6, 0.01)); // 大号字体
    expect(await scaledAt(2.0), closeTo(108.8, 0.01)); // 1.6封顶
  });
}
