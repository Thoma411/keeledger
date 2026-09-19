/*
 * @Author: Thoma4
 * @Date: 2026-06-24 00:55:11
 * @LastEditTime: 2026-09-19 12:31:00
 * @Description: 构建字母索引导航栏
 */

import 'package:flutter/material.dart';

import '../utils/app_text.dart';

class AlphabetIndexer extends StatefulWidget {
  final Map<String, int> alphabetIndexMap;
  final ValueChanged<String> onLetterSelected;
  final bool alignRight;

  const AlphabetIndexer({
    super.key,
    required this.alphabetIndexMap,
    required this.onLetterSelected,
    this.alignRight = false, // 默认电脑模式居左
  });

  @override
  State<AlphabetIndexer> createState() => _AlphabetIndexerState();
}

class _AlphabetIndexerState extends State<AlphabetIndexer> {
  static const List<String> _alphabet = [
    '#',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];
  static const Key _bubbleKey = Key('alphabetIndexerBubble');
  static const Key _activeKey = Key('alphabetIndexerActive');

  String? _activeChar; // 当前按住/滑到的字母(用于高亮与中央气泡)
  OverlayEntry? _bubbleEntry; // 中央字母气泡

  @override
  void dispose() {
    _bubbleEntry?.remove();
    super.dispose();
  }

  // 依据触点纵坐标定位首字母(按住滑动即可连续切换)
  void _selectLetterAt(Offset localPosition, double itemHeight) {
    final int index = (localPosition.dy / itemHeight).floor().clamp(
      0,
      _alphabet.length - 1,
    );
    final String char = _alphabet[index];
    if (char == _activeChar) return; // 同一字母不重复触发
    setState(() => _activeChar = char);
    _bubbleEntry?.markNeedsBuild(); // 气泡内容跟随更新
    if (widget.alphabetIndexMap.containsKey(char)) {
      widget.onLetterSelected(char);
    }
  }

  // 按下时在屏幕中央显示当前字母的大气泡
  void _showBubble() {
    if (_bubbleEntry != null) return;
    final OverlayState? overlay = Overlay.maybeOf(context);
    if (overlay == null) return; // 无Overlay环境则静默跳过
    final entry = OverlayEntry(builder: _buildBubble);
    overlay.insert(entry);
    _bubbleEntry = entry;
  }

  void _hideBubble() {
    _bubbleEntry?.remove();
    _bubbleEntry = null;
    if (_activeChar != null) setState(() => _activeChar = null);
  }

  Widget _buildBubble(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.inverseSurface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              _activeChar ?? '',
              key: _bubbleKey,
              textScaler: TextScaler.noScaling, // 固定不缩放
              style: TextStyle(
                fontSize: AppText.bubble,
                fontWeight: FontWeight.bold,
                color: cs.onInverseSurface,
                decoration: TextDecoration.underline, // 字母下划线
                decorationStyle: TextDecorationStyle.solid, // 单线
                decorationColor: cs.primary, // 下划线颜色
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: widget.alignRight ? 16 : 25, // 宽度
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 字母等分高度, 用于把触点纵坐标换算为字母下标
          final double itemHeight = constraints.maxHeight / _alphabet.length;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // 占位: 吞掉点击, 避免穿透到页面触发(如误关详情面板)
            child: Listener(
              behavior: HitTestBehavior.opaque, // 整个字母区域都可响应
              onPointerDown: (e) {
                _showBubble();
                _selectLetterAt(e.localPosition, itemHeight);
              },
              onPointerMove: (e) =>
                  _selectLetterAt(e.localPosition, itemHeight),
              onPointerUp: (_) => _hideBubble(), // 松开后同一字母可再次触发
              onPointerCancel: (_) => _hideBubble(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _alphabet.map((char) {
                  final bool hasData = widget.alphabetIndexMap.containsKey(
                    char,
                  );
                  final bool isActive = char == _activeChar;
                  // 按下反馈: 当前字母加底色强调
                  return Expanded(
                    child: Center(
                      child: Container(
                        key: isActive ? _activeKey : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: isActive
                            ? BoxDecoration(
                                color: (hasData ? cs.primary : cs.onSurface)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              )
                            : null,
                        child: Text(
                          char,
                          textScaler: TextScaler.noScaling, // 固定不缩放
                          style: TextStyle(
                            fontSize: widget.alignRight
                                ? AppText.indexLetterNarrow
                                : AppText.indexLetter,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? (hasData ? cs.primary : cs.onSurfaceVariant)
                                : (hasData
                                      ? cs.primary
                                      : cs.onSurface.withValues(alpha: 0.15)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
