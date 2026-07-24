import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_service.dart';

/// 구독 등급.
enum PlanTier {
  /// 무료 — 기출문제 10% · AI 선생님 기능 30% 제한.
  free,

  /// 프리미엄(유료 구독) — 전체 콘텐츠 + AI 무제한/심화.
  premium,
}

/// 🔐 Gisaclub 구독/권한(Entitlement) 관리 서비스.
///
/// [보안 설계 원칙]
/// - 클라이언트(앱)의 구독 상태는 "표시(UX)"용 캐시일 뿐, **최종 권한 판정은
///   반드시 서버(Cloudflare Worker)가 한다.** 앱을 디컴파일/변조해도 서버가
///   무료 사용자에게 유료 콘텐츠 조각을 반환하지 않으므로 우회가 불가능하다.
/// - 이 클래스는 (1) 로컬 캐시된 등급을 빠르게 노출하고, (2) 서버로부터
///   구독 상태를 갱신(refresh)하며, (3) 무료 정책(노출 비율, AI 사용량)의
///   기준값을 제공한다.
/// - 실제 문제/해설 데이터는 이 앱에 동봉하지 않고, 서버가 세션 단위로만
///   권한 검증 후 스트리밍한다(ContentApi 참조).
class EntitlementService extends ChangeNotifier {
  EntitlementService._();
  static final EntitlementService instance = EntitlementService._();

  // ─────────────── 정책 상수(무료 티어 노출/사용 한도) ───────────────
  /// 무료: 각 과목/회차 기출문제의 노출 비율(10%).
  static const double kFreeQuestionRatio = 0.10;

  /// 무료: AI 선생님 "기능 강도" 비율(30%). 답변 길이·심화도·일일 횟수에 반영.
  static const double kFreeAiCapabilityRatio = 0.30;

  /// 무료: AI 선생님 하루 사용 가능 횟수.
  static const int kFreeAiDailyLimit = 5;

  /// 무료: AI 답변 최대 토큰(짧은 요약 수준).
  static const int kFreeAiMaxTokens = 400;

  /// 프리미엄: AI 답변 최대 토큰(심화 추론 포함).
  static const int kPremiumAiMaxTokens = 2048;

  // ─────────────── 로컬 저장 키 ───────────────
  static const _kPlan = 'ent_plan_tier';
  static const _kExpiry = 'ent_expiry_iso';
  static const _kAiUsedDate = 'ent_ai_used_date';
  static const _kAiUsedCount = 'ent_ai_used_count';

  /// 서버(Cloudflare Worker) 엔드포인트. 실제 배포 시 --dart-define로 주입.
  static const _entitlementApiBase = String.fromEnvironment(
    'GISACLUB_API_BASE',
    defaultValue: 'https://api.gisaclub.com',
  );

  PlanTier _plan = PlanTier.free;
  DateTime? _expiry;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  PlanTier get plan => _plan;

  /// 프리미엄(유료) 활성 여부. 만료일이 지났으면 자동으로 free 취급.
  ///
  /// 🛡️ 관리자 오버라이드: 관리자 세션이 활성이면 결제 여부와 무관하게
  /// 항상 프리미엄으로 취급한다(전 콘텐츠·AI 무제한). 운영자가 앱을
  /// 검수·시연·고객지원할 때 모든 기능에 즉시 접근하도록 하기 위함이다.
  bool get isPremium {
    if (AdminService.instance.isAdmin) return true;
    if (_plan != PlanTier.premium) return false;
    final exp = _expiry;
    if (exp != null && DateTime.now().isAfter(exp)) return false;
    return true;
  }

  /// 관리자(운영자) 오버라이드로 프리미엄이 된 것인지 여부(배지 표시용).
  bool get isAdminOverride => AdminService.instance.isAdmin;

  bool get isFree => !isPremium;
  DateTime? get expiry => _expiry;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final planStr = prefs.getString(_kPlan);
      _plan = planStr == 'premium' ? PlanTier.premium : PlanTier.free;
      final expStr = prefs.getString(_kExpiry);
      _expiry = expStr != null ? DateTime.tryParse(expStr) : null;
    } catch (_) {
      _plan = PlanTier.free;
      _expiry = null;
    }
    _initialized = true;
    notifyListeners();
    // 서버 상태 동기화는 백그라운드로(앱 시작 지연 방지).
    unawaited(refreshFromServer());
  }

  /// 🔐 서버(Cloudflare)에서 구독 상태를 재확인한다.
  /// 서버가 최종 진실원이며, 로컬 캐시는 이 값으로 갱신된다.
  Future<void> refreshFromServer({String? authToken}) async {
    if (authToken == null || authToken.isEmpty) return; // 로그인 전이면 스킵
    try {
      final res = await http.get(
        Uri.parse('$_entitlementApiBase/v1/entitlement'),
        headers: {'Authorization': 'Bearer $authToken'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final tier = (body['tier'] as String?) ?? 'free';
      final expiryStr = body['expiry'] as String?;
      await _applyServerState(tier, expiryStr);
    } catch (e) {
      if (kDebugMode) debugPrint('entitlement refresh 실패: $e');
      // 실패 시 로컬 캐시 유지(오프라인 사용성). 유료 콘텐츠는 어차피
      // 서버 접근 시 재검증되므로 보안상 문제 없음.
    }
  }

  Future<void> _applyServerState(String tier, String? expiryIso) async {
    _plan = tier == 'premium' ? PlanTier.premium : PlanTier.free;
    _expiry = expiryIso != null ? DateTime.tryParse(expiryIso) : null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPlan, tier == 'premium' ? 'premium' : 'free');
      if (_expiry != null) {
        await prefs.setString(_kExpiry, _expiry!.toIso8601String());
      } else {
        await prefs.remove(_kExpiry);
      }
    } catch (_) {}
    notifyListeners();
  }

  /// 🛡️ 관리자(운영자) 전용: 구독 상태를 로컬에서 강제 설정(시연/테스트용).
  /// ⚠️ 실제 결제 검증은 서버가 하므로, 이 값은 서버 콘텐츠 접근을 보장하지 않는다.
  /// (관리자 오버라이드로 이미 전 기능이 열려 있으므로, 이 메서드는 무료/유료
  ///  UI 흐름을 관리자 화면에서 재현·검수할 때 사용한다.)
  Future<void> adminSetPlan(PlanTier tier, {DateTime? expiry}) =>
      debugSetPlan(tier, expiry: expiry);

  /// 개발/데모용: 구독 상태를 로컬에서 강제 설정(서버 없이 UI 흐름 확인).
  /// ⚠️ 실제 결제 검증은 서버가 하므로, 이 값은 콘텐츠 접근을 보장하지 않는다.
  @visibleForTesting
  Future<void> debugSetPlan(PlanTier tier, {DateTime? expiry}) async {
    _plan = tier;
    _expiry = expiry;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPlan,
        tier == PlanTier.premium ? 'premium' : 'free',
      );
      if (expiry != null) {
        await prefs.setString(_kExpiry, expiry.toIso8601String());
      } else {
        await prefs.remove(_kExpiry);
      }
    } catch (_) {}
    notifyListeners();
  }

  // ─────────────── 무료 기출문제 노출 게이트 ───────────────
  /// 전체 [total] 문항 중 무료 사용자가 접근 가능한 문항 수.
  int allowedQuestionCount(int total) {
    if (isPremium) return total;
    if (total <= 0) return 0;
    // 최소 1문항은 맛보기로 보장, 최대 10%.
    final n = (total * kFreeQuestionRatio).floor();
    return n < 1 ? 1 : n;
  }

  /// [index]번째(0-based) 문항이 무료 사용자에게 잠겨 있는지.
  bool isQuestionLocked(int index, int total) {
    if (isPremium) return false;
    return index >= allowedQuestionCount(total);
  }

  // ─────────────── AI 선생님 사용량 게이트(무료 30%) ───────────────
  /// 오늘 AI를 몇 번 썼는지.
  Future<int> _aiUsedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();
      final savedDate = prefs.getString(_kAiUsedDate);
      if (savedDate != today) return 0; // 날짜 바뀌면 리셋
      return prefs.getInt(_kAiUsedCount) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// AI 사용 가능 여부(무료: 일일 한도 이내). 프리미엄은 항상 true.
  Future<bool> canUseAi() async {
    if (isPremium) return true;
    final used = await _aiUsedToday();
    return used < kFreeAiDailyLimit;
  }

  /// 남은 무료 AI 사용 횟수(프리미엄은 -1 = 무제한).
  Future<int> remainingAiUses() async {
    if (isPremium) return -1;
    final used = await _aiUsedToday();
    final left = kFreeAiDailyLimit - used;
    return left < 0 ? 0 : left;
  }

  /// AI 1회 사용 기록(무료 카운트 증가). 프리미엄은 카운트하지 않음.
  Future<void> recordAiUse() async {
    if (isPremium) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();
      final savedDate = prefs.getString(_kAiUsedDate);
      final cur = (savedDate == today) ? (prefs.getInt(_kAiUsedCount) ?? 0) : 0;
      await prefs.setString(_kAiUsedDate, today);
      await prefs.setInt(_kAiUsedCount, cur + 1);
    } catch (_) {}
  }

  /// 현재 등급에 맞는 AI 답변 최대 토큰.
  int aiMaxTokens() => isPremium ? kPremiumAiMaxTokens : kFreeAiMaxTokens;

  /// 현재 등급에 맞는 AI 추론 강도(low=무료 축약 / high=프리미엄 심화).
  String aiReasoningEffort() => isPremium ? 'high' : 'low';

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}
