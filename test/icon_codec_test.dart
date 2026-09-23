/*
 * @Author: Thoma4
 * @Date: 2026-09-23 22:41:32
 * @LastEditTime: 2026-09-23 23:23:47
 * @Description: 图标解码与缩放测试
 */

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keeledger/utils/icon_codec.dart';

// 生成指定尺寸的纯色PNG
Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFF3366FF),
  );
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('超过上限的图标等比缩到 256px', () async {
    final out = await IconCodec.normalize(await _png(512, 512));
    final image = await _decode(out);
    expect(image.width, 256);
    expect(image.height, 256);
    image.dispose();
  });

  test('非正方形图标按长边缩放', () async {
    final out = await IconCodec.normalize(await _png(600, 300));
    final image = await _decode(out);
    expect(image.width, 256);
    expect(image.height, 128);
    image.dispose();
  });

  test('未超过上限的图标原样返回', () async {
    final raw = await _png(128, 96);
    expect(identical(await IconCodec.normalize(raw), raw), isTrue);
  });
}
