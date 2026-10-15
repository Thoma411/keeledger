/*
 * @Author: Thoma4
 * @Date: 2026-10-09 22:58:20
 * @LastEditTime: 2026-10-15 23:33:09
 * @Description: 常用信息实体定义
 */

import '../services/security_service.dart';

// 常用信息类型
enum PresetKind {
  nickname('nickname', '用户昵称'),
  password('password', '密码'),
  email('email', '绑定邮箱'),
  phone('phone', '绑定手机');

  const PresetKind(this.code, this.label);

  final String code; // 落库值
  final String label; // 界面显示名

  // 未知code兜底为第一个类型
  static PresetKind fromCode(String? code) =>
      values.firstWhere((k) => k.code == code, orElse: () => nickname);
}

// 内容规范化(除密码外去除首尾空格)
String _normalizeValue(PresetKind kind, String value) =>
    kind == PresetKind.password ? value : value.trim();

class Preset {
  static const int maxPerKind = 8; // 每类最大保存上限
  final String id;
  String name; // 名称(简称)
  PresetKind kind; // 类型
  String value; // 内容
  String lastModified;

  Preset({
    required this.id,
    required String name,
    required this.kind,
    required String value,
    required this.lastModified,
  }) : name = name.trim(),
       value = _normalizeValue(kind, value);

  // 转换为数据库存储的Map
  Map<String, dynamic> toMap() {
    final sec = SecurityService();
    final dk = sec.currentDataKey;
    return {
      'id': id,
      'name': name,
      'kind': kind.code,
      'value': (dk != null && value.isNotEmpty)
          ? sec.encrypt(value, dk)
          : value,
      'last_modified': lastModified,
    };
  }

  // 从数据库Map还原
  factory Preset.fromMap(Map<String, dynamic> map) {
    final sec = SecurityService();
    final dk = sec.currentDataKey;
    final String raw = (map['value'] ?? '').toString();
    String value = raw;
    if (raw.isNotEmpty && dk != null) {
      try {
        value = sec.decrypt(raw, dk);
      } catch (_) {
        value = "[解密失败]";
      }
    }
    return Preset(
      id: map['id'],
      name: map['name'] ?? '',
      kind: PresetKind.fromCode(map['kind']),
      value: value,
      lastModified: map['last_modified'] ?? DateTime.now().toIso8601String(),
    );
  }
}
