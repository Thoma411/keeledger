/*
 * @Author: Thoma4
 * @Date: 2026-09-23 22:36:44
 * @LastEditTime: 2026-09-23 23:23:37
 * @Description: 图标解码与缩放
 */

import 'dart:typed_data';
import 'dart:ui' as ui;

class IconCodec {
  IconCodec._();

  static const int maxSize = 256; // 图标边长上限

  // 超过上限才等比缩到上限并转PNG; 未超过则原样返回(保留原始格式与质量)
  static Future<Uint8List> normalize(Uint8List raw) async {
    final ui.Codec codec = await ui.instantiateImageCodec(raw);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final int w = frame.image.width;
    final int h = frame.image.height;
    frame.image.dispose();
    if (w <= maxSize && h <= maxSize) return raw;

    final bool landscape = w >= h;
    final int targetW = landscape ? maxSize : (w * maxSize / h).round();
    final int targetH = landscape ? (h * maxSize / w).round() : maxSize;
    final ui.Codec scaled = await ui.instantiateImageCodec(
      raw,
      targetWidth: targetW,
      targetHeight: targetH,
    );
    final ui.FrameInfo out = await scaled.getNextFrame();
    final ByteData? png = await out.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    out.image.dispose();
    return png!.buffer.asUint8List();
  }
}
