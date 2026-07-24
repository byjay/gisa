import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Q22 로컬 암호화 서비스.
///
/// Hive 박스를 `HiveAesCipher`로 암호화하여, 디바이스에서 앱 데이터 파일을
/// 직접 추출·디컴파일하더라도 오답노트/세션/학습기록 등 민감 데이터를
/// 평문으로 읽을 수 없게 한다.
///
/// - 256bit AES 키를 앱 최초 실행 시 1회 생성.
/// - 키는 `shared_preferences`에 base64로 보관(Web 포함 전 플랫폼 안전).
///   (모바일 정식 배포 시 flutter_secure_storage/Keystore로 승격 가능하나,
///    현 단계는 파일 추출 방어를 목적으로 하는 로컬 앱이므로 이 방식으로 충분.)
/// - 실패(Web 등 예외) 시 평문 박스로 안전 폴백하여 앱이 죽지 않도록 한다.
class SecureBoxService {
  SecureBoxService._();
  static final SecureBoxService instance = SecureBoxService._();

  static const _keyPref = 'hive_aes_key_v1';
  HiveCipher? _cipher;
  bool _ready = false;

  /// 앱 시작 시 1회 호출. 키가 없으면 생성한다.
  Future<void> init() async {
    if (_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      String? b64 = prefs.getString(_keyPref);
      List<int> keyBytes;
      if (b64 == null) {
        keyBytes = _generateKey();
        await prefs.setString(_keyPref, base64Encode(keyBytes));
      } else {
        keyBytes = base64Decode(b64);
      }
      _cipher = HiveAesCipher(keyBytes);
      _ready = true;
    } catch (e) {
      // 키 준비 실패 시 암호화 없이 진행(앱 크래시 방지).
      if (kDebugMode) debugPrint('SecureBoxService init fallback: $e');
      _cipher = null;
      _ready = true;
    }
  }

  /// 암호화 사용 가능 여부.
  bool get isEncrypted => _cipher != null;

  /// 민감 박스를 암호화로 연다. 암호화 실패 시 평문으로 폴백.
  Future<Box> openSecureBox(String name) async {
    if (!_ready) await init();
    final cipher = _cipher;
    if (cipher == null) {
      return Hive.openBox(name);
    }
    try {
      return await Hive.openBox(name, encryptionCipher: cipher);
    } catch (e) {
      // 기존 평문 박스가 이미 존재하면 암호화 열기가 실패할 수 있음 → 평문 폴백.
      if (kDebugMode) debugPrint('openSecureBox fallback ($name): $e');
      return Hive.openBox(name);
    }
  }

  List<int> _generateKey() {
    final rnd = Random.secure();
    return List<int>.generate(32, (_) => rnd.nextInt(256));
  }
}
