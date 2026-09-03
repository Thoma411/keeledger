/*
 * @Author: Thoma4
 * @Date: 2026-02-12 22:42:38
 * @LastEditTime: 2026-09-03 22:26:02
 * @Description: CSV处理
 */

import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/account.dart';
import 'account_csv_mapper.dart';
import 'storage_service.dart';

// CSV导入结果(供UI展示)
class CsvImportResult {
  final String? error; // 非null=整个文件被拒绝(表头级问题/读取异常)
  final int success;
  final int skippedDuplicate; // 库中已存在同名平台
  final int skippedInvalid; // 行级问题(缺平台/解析失败)
  final int ignoredColumns; // 表头未识别列数
  const CsvImportResult({
    this.error,
    this.success = 0,
    this.skippedDuplicate = 0,
    this.skippedInvalid = 0,
    this.ignoredColumns = 0,
  });
}

class CsvService {
  final StorageService _storageService = StorageService();

  // 唤起文件选择并导入CSV数据
  Future<CsvImportResult> pickAndImportCsv() async {
    try {
      // 1. 选择文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.single.path == null) {
        return const CsvImportResult(); // 用户取消
      }
      // 2. 读取文件
      final File file = File(result.files.single.path!);
      final String csvContent = await file.readAsString(encoding: utf8);
      // 3. 解析CSV
      final List<List<dynamic>> rows = const CsvToListConverter().convert(
        csvContent,
      );
      if (rows.length < 2) {
        return const CsvImportResult(error: 'CSV 内容为空或缺少数据行');
      }
      // 4. 解析表头
      final ({Map<String, int> index, int ignoredColumns}) header;
      try {
        header = parseCsvHeader(rows[0]);
      } on CsvFormatException catch (e) {
        return CsvImportResult(error: e.message);
      }
      // 5. 读取库中现存条目平台名(用于查重)
      final existingAccounts = await _storageService.getAllAccounts();
      final Set<String> existingNames = existingAccounts
          .map((a) => a.platform.toLowerCase().trim())
          .toSet();
      int successCount = 0, duplicateCount = 0, invalidCount = 0;
      // 6. 逐行解析导入(第1行为表头, 从第2行开始)
      for (int i = 1; i < rows.length; i++) {
        try {
          final currentCount = await _storageService.getAccountCount();
          if (currentCount >= 4096) {
            debugPrint("已达数据库设定上限(4096)，导入中止");
            break;
          }
          final row = rows[i];
          // 跳过全空行
          if (row.isEmpty ||
              row.every((c) => c?.toString().trim().isEmpty ?? true)) {
            continue;
          }
          // 按表头映射解析
          final Account? acc = accountFromCsvRow(row, header.index);
          if (acc == null) {
            invalidCount++; // 缺平台名
            continue;
          }
          final platformName = acc.platform.toLowerCase().trim();
          if (existingNames.contains(platformName)) {
            duplicateCount++;
            continue;
          }
          await _storageService.insertAccount(acc);
          existingNames.add(platformName); // 更新存在(重名)列表
          successCount++;
        } catch (e) {
          debugPrint("导入第 $i 行失败: $e");
          invalidCount++;
        }
      }
      return CsvImportResult(
        success: successCount,
        skippedDuplicate: duplicateCount,
        skippedInvalid: invalidCount,
        ignoredColumns: header.ignoredColumns,
      );
    } catch (e) {
      debugPrint("CSV导入服务异常: $e");
      return CsvImportResult(error: '导入失败: $e');
    }
  }

  // 导出为CSV(注册表驱动: 表头=规范列名, 顺序由注册表决定)
  Future<int?> exportToCsv() async {
    try {
      // 1. 获取全量数据
      final accounts = await _storageService.getAllAccounts();
      if (accounts.isEmpty) throw Exception("数据库中暂无数据可导出");
      // 按a-z排序
      accounts.sort((a, b) {
        int cmp = a.platformPinyin.compareTo(b.platformPinyin); // 比较拼音
        if (cmp == 0) cmp = a.platform.compareTo(b.platform); // 拼音相同比较原字符
        return cmp; // 默认升序
      });
      // 2. 构建CSV列表(首行为规范表头)
      final List<List<dynamic>> csvData = [csvHeader()];
      csvData.addAll(accounts.map((acc) => accountToCsvRow(acc)));
      // 3. 转换为CSV字符串 + UTF-8 BOM
      final String csvString = const ListToCsvConverter().convert(csvData);
      final List<int> bom = [0xEF, 0xBB, 0xBF]; // 添加UTF-8 BOM头
      final List<int> content = utf8.encode(csvString);
      final Uint8List fileBytes = Uint8List.fromList(
        bom + content,
      ); // 转换成标准Uint8List
      // 4. 调用保存对话框
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '选择导出路径',
        fileName:
            'keeledger_export_${DateTime.now().millisecondsSinceEpoch}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: fileBytes,
      );
      if (outputFile == null) return null; // 用户取消
      // 5. 写入文件(仅在桌面端手动writeAsBytes写盘)
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // 让Windows Excel自动识别为UTF-8编码，防止中文乱码
        final File file = File(outputFile);
        await file.writeAsBytes(fileBytes);
      }
      return accounts.length;
    } catch (e) {
      debugPrint("导出失败: $e");
      rethrow;
    }
  }
}
