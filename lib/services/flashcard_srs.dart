import 'package:hive_flutter/hive_flutter.dart';

/// 🃏 암기법 플래시카드 간격반복(SRS) 서비스.
/// "안다/모른다" 두 버튼으로 학습 — 아는 카드는 멀리 미루고, 모르는 카드는
/// 자주 다시 보게 만들어 암기 과목이 "쏙쏙 들어오게" 만드는 핵심 엔진.
class FlashcardSrs {
  FlashcardSrs._();
  static final FlashcardSrs instance = FlashcardSrs._();

  Box? _box; // cardKey -> {box, nextDue, seen, known}
  bool _ready = false;

  static const List<int> _intervalDays = [0, 1, 2, 4, 8, 16]; // box 0~5

  Future<void> _ensure() async {
    if (_ready) return;
    _box = await Hive.openBox('flashcardSrs');
    _ready = true;
  }

  Map<String, dynamic> _rec(String key) {
    final raw = _box?.get(key);
    if (raw == null) return {'box': 0, 'seen': 0, 'known': 0};
    return Map<String, dynamic>.from(raw);
  }

  /// "안다" → 박스 +1(간격 늘어남) / "모른다" → 박스 0(내일 다시)
  Future<void> mark(String key, bool known) async {
    await _ensure();
    final r = _rec(key);
    r['seen'] = (r['seen'] as int? ?? 0) + 1;
    if (known) r['known'] = (r['known'] as int? ?? 0) + 1;
    final box = known
        ? ((r['box'] as int? ?? 0) + 1).clamp(0, _intervalDays.length - 1)
        : 0;
    r['box'] = box;
    r['nextDue'] =
        DateTime.now().add(Duration(days: _intervalDays[box])).toIso8601String();
    await _box!.put(key, r);
  }

  Future<int> boxOf(String key) async {
    await _ensure();
    return _rec(key)['box'] as int? ?? 0;
  }

  /// 오늘 복습해야 할 카드 키 집합 (박스 5=완전 암기 제외)
  Future<Set<String>> dueKeys() async {
    await _ensure();
    final now = DateTime.now();
    final out = <String>{};
    for (final key in _box!.keys) {
      final r = _rec(key as String);
      final due = r['nextDue'] as String?;
      final box = r['box'] as int? ?? 0;
      if (due == null) continue; // 한 번도 안 본 카드는 별도 처리(신규)
      if (box >= _intervalDays.length - 1) continue;
      final dueDate = DateTime.tryParse(due);
      if (dueDate == null) continue;
      if (!dueDate.isAfter(now)) out.add(key);
    }
    return out;
  }

  Future<Set<String>> seenKeys() async {
    await _ensure();
    return _box!.keys.map((e) => e as String).toSet();
  }

  /// 완전 암기(box 5) 카드 키 집합
  Future<Set<String>> masteredKeys() async {
    await _ensure();
    final out = <String>{};
    for (final key in _box!.keys) {
      final r = _rec(key as String);
      if ((r['box'] as int? ?? 0) >= _intervalDays.length - 1) out.add(key);
    }
    return out;
  }
}
