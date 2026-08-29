/*
 * @Author: Thoma4
 * @Date: 2026-08-29 17:46:49
 * @LastEditTime: 2026-08-29 18:16:03
 * @Description: 更新检查服务
 */

import 'dart:convert';
import 'package:http/http.dart' as http;

// 更新信息模型
class UpdateInfo {
  final String remoteVersion;
  final String downloadUrl; // release页面
  final String releaseNotes; // 更新说明
  final String apkDownloadUrl; // APK直链(可能为空)
  const UpdateInfo({
    required this.remoteVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.apkDownloadUrl,
  });
}

class UpdateService {
  static const String _apiUrl =
      "https://api.github.com/repos/Thoma411/keeledger/releases";
  static const String _apkName = "keeledger-arm64-v8a-release.apk";

  // 版本解析(解析 "v1.2.3" / "1.10.0" 为 [1, 2, 3])
  static List<int>? parseVersion(String tag) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(tag.trim());
    if (m == null) return null;
    return [
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    ];
  }

  // 版本比较
  static bool isNewer(String a, String b) {
    final va = parseVersion(a);
    final vb = parseVersion(b);
    if (va == null || vb == null) return false;
    for (var i = 0; i < 3; i++) {
      if (va[i] != vb[i]) return va[i] > vb[i];
    }
    return false; // 完全相等
  }

  // 选最新版本号
  static Map<String, dynamic>? pickLatest(List<dynamic> releases) {
    Map<String, dynamic>? best;
    String? bestTag;
    for (final raw in releases) {
      if (raw is! Map) continue;
      final tag = raw['tag_name']?.toString() ?? '';
      if (parseVersion(tag) == null) continue; // 跳过无法解析的条目
      if (bestTag == null || isNewer(tag, bestTag)) {
        best = Map<String, dynamic>.from(raw);
        bestTag = tag;
      }
    }
    return best;
  }

  // 检查更新
  Future<UpdateInfo?> checkForUpdates() async {
    final url = Uri.parse(_apiUrl);
    final response = await http.get(url).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception("HTTP 状态码 ${response.statusCode}");
    }
    final List<dynamic> releases = jsonDecode(response.body);
    final latest = pickLatest(releases);
    if (latest == null) return null;

    final String remoteVersion = latest['tag_name']?.toString() ?? "";
    final String downloadUrl = latest['html_url']?.toString() ?? "";
    final String releaseNotes = latest['body']?.toString() ?? "暂无更新说明。";

    // 提取APK直链
    String apkDownloadUrl = "";
    final List<dynamic>? assets = latest['assets'];
    if (assets != null) {
      for (final asset in assets) {
        if (asset is Map && asset['name'] == _apkName) {
          apkDownloadUrl = asset['browser_download_url']?.toString() ?? "";
          break;
        }
      }
    }

    return UpdateInfo(
      remoteVersion: remoteVersion,
      downloadUrl: downloadUrl,
      releaseNotes: releaseNotes,
      apkDownloadUrl: apkDownloadUrl,
    );
  }
}
