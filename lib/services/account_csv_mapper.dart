/*
 * @Author: Thoma4
 * @Date: 2026-09-03 21:33:45
 * @LastEditTime: 2026-09-03 23:47:33
 * @Description: 账户CSV字段注册表与映射
 */

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';

// 表头级错误(重复列/缺必填列)拒绝整个文件
class CsvFormatException implements Exception {
  final String message;
  CsvFormatException(this.message);
  @override
  String toString() => message;
}

// 单字段的CSV映射描述
class AccountCsvField {
  final String key; // 规范列名
  final bool required; // 是否必填(缺失则该文件被拒绝)
  final List<String> aliases; // 兼容旧表头(匹配时大小写不敏感)
  final String Function(Account account) export; // 导出为字符串
  final Object? Function(String raw) parse; // 解析
  const AccountCsvField({
    required this.key,
    this.required = false,
    this.aliases = const [],
    required this.export,
    required this.parse,
  });
}

// 通用工具
DateTime? _parseCsvDate(String raw) {
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw.replaceAll(RegExp(r'[/.]'), '-'));
}

String _fmtDate(DateTime? dt) =>
    dt == null ? "" : DateFormat('yyyy-MM-dd').format(dt);

// 解析函数(空串->默认值)
Object? _rawStr(String raw) => raw;
Object? _nullableStr(String raw) => raw.isEmpty ? null : raw;
Object? _parseDate(String raw) => _parseCsvDate(raw);
Object? _parseFlag(String raw) =>
    raw == '1' || raw.toLowerCase() == 'true' || raw == '是';
Object? _parseTags(String raw) => raw.isEmpty
    ? const <String>[]
    : raw
          .split(RegExp(r'[,，]'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
Object? _parseStatus(String raw) => int.tryParse(raw) ?? 1;

// 导出访问器
String _expPlatform(Account a) => a.platform;
String _expName(Account a) => a.name;
String _expUserId(Account a) => a.userId;
String _expEmail(Account a) => a.email;
String _expPswd(Account a) => a.pswd;
String _expUrl(Account a) => a.url;
String _expPhone(Account a) => a.phone;
String _expBirth(Account a) => _fmtDate(a.birth);
String _expNotes(Account a) => a.notes ?? "";
String _expSignup(Account a) => _fmtDate(a.signupDate);
String _expRealName(Account a) => a.realName ? '1' : '0';
String _expFavorite(Account a) => a.favorite ? '1' : '0';
String _expTags(Account a) => a.tags.join(',');
String _expStatus(Account a) => a.status.toString();

// 字段注册表: 顺序即导出表头顺序; 加新字段在此追加(含Account构建处)
// *设计: 规范列名 == DB列名 == 导出表头; 导入按表头列名匹配而非固定位置
const List<AccountCsvField> kAccountCsvFields = [
  AccountCsvField(
    key: 'platform',
    required: true,
    export: _expPlatform,
    parse: _rawStr,
  ),
  AccountCsvField(key: 'name', export: _expName, parse: _rawStr),
  AccountCsvField(
    key: 'user_id',
    aliases: ['USER_ID', 'userId'],
    export: _expUserId,
    parse: _rawStr,
  ),
  AccountCsvField(
    key: 'email',
    aliases: ['EMAIL'],
    export: _expEmail,
    parse: _rawStr,
  ),
  AccountCsvField(
    key: 'pswd',
    aliases: ['PSWD', 'password'],
    export: _expPswd,
    parse: _rawStr,
  ),
  AccountCsvField(key: 'url', export: _expUrl, parse: _rawStr),
  AccountCsvField(
    key: 'phone',
    aliases: ['PHONE'],
    export: _expPhone,
    parse: _rawStr,
  ),
  AccountCsvField(key: 'birth', export: _expBirth, parse: _parseDate),
  AccountCsvField(key: 'notes', export: _expNotes, parse: _nullableStr),
  AccountCsvField(
    key: 'signup_date',
    aliases: ['signupDate'],
    export: _expSignup,
    parse: _parseDate,
  ),
  AccountCsvField(
    key: 'real_name',
    aliases: ['realName'],
    export: _expRealName,
    parse: _parseFlag,
  ),
  AccountCsvField(
    key: 'tags',
    aliases: ['tag'],
    export: _expTags,
    parse: _parseTags,
  ),
  AccountCsvField(key: 'status', export: _expStatus, parse: _parseStatus),
  // 补列字段
  AccountCsvField(key: 'favorite', export: _expFavorite, parse: _parseFlag),
];

// 解析表头: 返回 (规范列名->列索引, 未识别列数)
// 表头含重复列或缺少必填列(platform)时抛CsvFormatException
({Map<String, int> index, int ignoredColumns}) parseCsvHeader(
  List<dynamic> headerRow,
) {
  // 建立"小写列名/别名->字段"的查找表
  final lookup = <String, AccountCsvField>{};
  for (final f in kAccountCsvFields) {
    lookup[f.key.toLowerCase()] = f;
    for (final alias in f.aliases) {
      lookup[alias.toLowerCase()] = f;
    }
  }

  final index = <String, int>{};
  final seen = <String>{};
  var ignored = 0;
  for (var i = 0; i < headerRow.length; i++) {
    final cell = headerRow[i]?.toString().trim() ?? '';
    if (cell.isEmpty) continue;
    final field = lookup[cell.toLowerCase()];
    if (field == null) {
      ignored++; // 未知列忽略
      continue;
    }
    if (!seen.add(field.key)) {
      throw CsvFormatException('表头中存在重复列: "${field.key}"');
    }
    index[field.key] = i;
  }
  // 必填列检查
  for (final f in kAccountCsvFields) {
    if (f.required && !index.containsKey(f.key)) {
      throw CsvFormatException('表头缺少必填列: "${f.key}"');
    }
  }
  return (index: index, ignoredColumns: ignored);
}

// 按表头映射将一行解析为Account
Account? accountFromCsvRow(List<dynamic> row, Map<String, int> headerIndex) {
  String cell(String key) {
    final idx = headerIndex[key];
    if (idx == null || idx >= row.length) return '';
    final v = row[idx];
    return v == null ? '' : v.toString().trim();
  }

  final platform = cell('platform');
  if (platform.isEmpty) return null;

  final parsed = <String, Object?>{};
  for (final f in kAccountCsvFields) {
    parsed[f.key] = f.parse(cell(f.key));
  }

  return Account(
    id: const Uuid().v4(),
    platform: platform,
    name: (parsed['name'] as String?) ?? '',
    userId: (parsed['user_id'] as String?) ?? '',
    email: (parsed['email'] as String?) ?? '',
    pswd: (parsed['pswd'] as String?) ?? '',
    url: (parsed['url'] as String?) ?? '',
    phone: (parsed['phone'] as String?) ?? '',
    birth: parsed['birth'] as DateTime?,
    notes: parsed['notes'] as String?,
    signupDate: parsed['signup_date'] as DateTime?,
    realName: (parsed['real_name'] as bool?) ?? false,
    tags: (parsed['tags'] as List<String>?) ?? const [],
    status: (parsed['status'] as int?) ?? 1,
    favorite: (parsed['favorite'] as bool?) ?? false,
    lastModified: DateTime.now().toIso8601String(),
  );
}

// 导出的表头(规范列名, 为字段注册表顺序)
List<String> csvHeader() => [for (final f in kAccountCsvFields) f.key];

// 将账户序列化为一行(顺序与表头一致)
List<String> accountToCsvRow(Account account) => [
  for (final f in kAccountCsvFields) f.export(account),
];
