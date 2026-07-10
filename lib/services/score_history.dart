import 'package:hive_flutter/hive_flutter.dart';

/// 📈 합격 예측 점수 히스토리 — "내가 나아지고 있다"는 증거를 남기는 서비스.
/// 하루 1개 스냅샷(날짜키)으로 저장 → 트렌드 그래프 + D-Day 역산에 사용.
class ScoreHistory {
  ScoreHistory._();
  static final ScoreHistory instance = ScoreHistory._();

  Box? _box;
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    _box = await Hive.openBox('scoreHistory');
    _ready = true;
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 오늘자 예측 점수 스냅샷 기록 (하루 1개, 마지막 값으로 갱신)
  Future<void> record(double overall, int totalAttempts) async {
    await _ensure();
    await _box!.put(_key(DateTime.now()), {
      'score': overall,
      'attempts': totalAttempts,
      'ts': DateTime.now().toIso8601String(),
    });
  }

  /// 최근 N일 히스토리 (날짜 오름차순), 데이터 없는 날은 생략
  Future<List<(DateTime, double, int)>> recent({int days = 14}) async {
    await _ensure();
    final now = DateTime.now();
    final out = <(DateTime, double, int)>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day - i);
      final raw = _box!.get(_key(d));
      if (raw != null) {
        final m = Map<String, dynamic>.from(raw);
        out.add((d, (m['score'] as num).toDouble(), m['attempts'] as int));
      }
    }
    return out;
  }

  /// 점수-시도수 상관 기울기(문제당 예상 상승폭) — D-Day 역산에 사용.
  /// 데이터가 부족하면 보수적 기본값 0.09점/문제 사용.
  Future<double> gainPerQuestion() async {
    final h = await recent(days: 30);
    if (h.length < 2) return 0.09;
    final first = h.first;
    final last = h.last;
    final dAttempts = last.$3 - first.$3;
    final dScore = last.$2 - first.$2;
    if (dAttempts < 20 || dScore <= 0) return 0.09;
    final slope = dScore / dAttempts;
    // 이상치 방지: 0.03~0.4 범위로 클램프
    return slope.clamp(0.03, 0.4);
  }
}
