import 'package:hive_flutter/hive_flutter.dart';

/// 슬라이드 학습 진도 영속화 (Hive)
class SlideProgress {
  SlideProgress._();
  static final SlideProgress instance = SlideProgress._();

  Box? _box;

  Future<Box> _open() async {
    _box ??= await Hive.openBox('slideProgress');
    return _box!;
  }

  Future<void> ensureReady() => _open();

  /// 진도 네임스페이스별 카드 수 키 (기본 30일 이론 = 접두사 없음, 과목요약 등은 접두사 부여)
  String _key(int day, String prefix) =>
      prefix.isEmpty ? 'seen_$day' : 'seen_${prefix}_$day';

  /// 덱별 본 카드 수 (최대 페이지+1)
  int seen(int day, {String prefix = ''}) =>
      (_box?.get(_key(day, prefix)) as int?) ?? 0;

  bool isDone(int day, int total, {String prefix = ''}) =>
      seen(day, prefix: prefix) >= total;

  Future<void> markSeen(
    int day,
    int pageIndex,
    int total, {
    String prefix = '',
  }) async {
    final b = await _open();
    final key = _key(day, prefix);
    final cur = (b.get(key) as int?) ?? 0;
    final v = pageIndex + 1;
    if (v > cur) await b.put(key, v.clamp(0, total));
    if (prefix.isEmpty) await b.put('lastDay', day);
  }

  int? get lastDay => _box?.get('lastDay') as int?;

  /// 전역 학습 난이도 (baby/standard/fast)
  String get level => (_box?.get('level') as String?) ?? 'standard';

  Future<void> setLevel(String v) async {
    final b = await _open();
    await b.put('level', v);
  }
}
