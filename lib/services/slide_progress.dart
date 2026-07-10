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

  /// 덱별 본 카드 수 (최대 페이지+1)
  int seen(int day) => (_box?.get('seen_$day') as int?) ?? 0;

  bool isDone(int day, int total) => seen(day) >= total;

  Future<void> markSeen(int day, int pageIndex, int total) async {
    final b = await _open();
    final cur = (b.get('seen_$day') as int?) ?? 0;
    final v = pageIndex + 1;
    if (v > cur) await b.put('seen_$day', v.clamp(0, total));
    await b.put('lastDay', day);
  }

  int? get lastDay => _box?.get('lastDay') as int?;

  /// 전역 학습 난이도 (baby/standard/fast)
  String get level => (_box?.get('level') as String?) ?? 'standard';

  Future<void> setLevel(String v) async {
    final b = await _open();
    await b.put('level', v);
  }
}
