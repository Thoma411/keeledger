/*
 * @Author: Thoma4
 * @Date: 2026-09-16 12:14:29
 * @LastEditTime: 2026-09-16 22:32:11
 * @Description: 生物识别硬件密钥存储(Android Keystore)
 */

import 'dart:convert';
import 'dart:io';

import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/foundation.dart';

// 生物识别可用性
enum BiometricAvailability {
  available, // 可用
  noHardware, // 设备不支持指纹硬件
  notEnrolled, // 有硬件但未录入指纹
  hwUnavailable, // 硬件暂时不可用
  unsupported, // 平台暂不支持(非Android)
}

// 读取硬件密钥结果状态
enum BiometricKeyStatus {
  ok, // 读取成功
  canceled, // 用户主动取消
  lockedOut, // 尝试次数过多被系统短暂锁定
  invalidated, // 密钥永久失效(指纹集合被改动等)
  missing, // 硬件存储中已无BK
  failed, // 其它异常
}

class BiometricKeyResult {
  const BiometricKeyResult(this.status, [this.key]);

  final BiometricKeyStatus status;
  final Uint8List? key;
}

// 硬件密钥存储抽象
abstract class BiometricKeyStore {
  Future<BiometricAvailability> availability(); // 查询可用性
  Future<BiometricKeyResult> readKey(); // 读取BK
  Future<bool> writeKey(Uint8List key); // 写入/覆盖BK
  Future<void> deleteKey(); // 删除BK
}

// 基于biometric_storage插件的实现
class PluginBiometricKeyStore implements BiometricKeyStore {
  static const String _storageName = 'keeledger_bk';
  static final PluginBiometricKeyStore _instance =
      PluginBiometricKeyStore._internal();
  factory PluginBiometricKeyStore() => _instance;
  PluginBiometricKeyStore._internal();

  // 提示文案
  static const PromptInfo _prompt = PromptInfo(
    androidPromptInfo: AndroidPromptInfo(
      title: '验证指纹',
      subtitle: '用于解锁 Keeledger',
      negativeButton: '取消',
      confirmationRequired: false,
    ),
  );

  static final StorageFileInitOptions _options = StorageFileInitOptions(
    authenticationRequired: true,
    androidBiometricOnly: true,
  );

  @override
  Future<BiometricAvailability> availability() async {
    if (!Platform.isAndroid) return BiometricAvailability.unsupported;
    try {
      final response = await BiometricStorage().canAuthenticate();
      switch (response) {
        case CanAuthenticateResponse.success:
          return BiometricAvailability.available;
        case CanAuthenticateResponse.errorNoHardware:
          return BiometricAvailability.noHardware;
        case CanAuthenticateResponse.errorNoBiometricEnrolled:
          return BiometricAvailability.notEnrolled;
        case CanAuthenticateResponse.errorHwUnavailable:
          return BiometricAvailability.hwUnavailable;
        default:
          return BiometricAvailability.unsupported;
      }
    } catch (e) {
      debugPrint('生物识别可用性检测失败: $e');
      return BiometricAvailability.hwUnavailable;
    }
  }

  Future<BiometricStorageFile> _file() => BiometricStorage().getStorage(
    _storageName,
    options: _options,
    promptInfo: _prompt,
  );

  @override
  Future<BiometricKeyResult> readKey() async {
    try {
      final String? data = await (await _file()).read();
      if (data == null) {
        return const BiometricKeyResult(BiometricKeyStatus.missing);
      }
      return BiometricKeyResult(BiometricKeyStatus.ok, base64.decode(data));
    } on AuthException catch (e) {
      // 用户主动取消/传感器超时
      if (e.code == AuthExceptionCode.userCanceled ||
          e.code == AuthExceptionCode.canceled ||
          e.code == AuthExceptionCode.timeout) {
        debugPrint('指纹认证未通过: ${e.code}');
        return const BiometricKeyResult(BiometricKeyStatus.canceled);
      }
      debugPrint('指纹暂时不可用: ${e.code} / ${e.message}');
      return const BiometricKeyResult(BiometricKeyStatus.lockedOut);
    } catch (e) {
      final String text = e.toString();
      // 指纹集合被改动会导致Keystore密钥永久失效
      if (text.contains('Invalidat')) {
        return const BiometricKeyResult(BiometricKeyStatus.invalidated);
      }
      debugPrint('读取指纹密钥失败: $e');
      return const BiometricKeyResult(BiometricKeyStatus.failed);
    }
  }

  @override
  Future<bool> writeKey(Uint8List key) async {
    try {
      await (await _file()).write(base64.encode(key));
      return true;
    } catch (e) {
      debugPrint('写入指纹密钥失败: $e');
      return false;
    }
  }

  @override
  Future<void> deleteKey() async {
    try {
      await (await _file()).delete();
    } catch (e) {
      debugPrint('删除指纹密钥失败: $e');
    }
  }
}
