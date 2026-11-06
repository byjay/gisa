import 'package:hive_flutter/hive_flutter.dart';
import 'progress_sync_service.dart';
import 'user_data_scope.dart';

/// 슬라이드 학습 진도 영속화 (Hive)
class SlideProgress {
  SlideProgress._();
  static final SlideProgress instance = SlideProgress._();

  Box? _box;
  String? _boxName;
  static const _lastDayTimestampKey = '__meta_last_day_updated_at';
  static const _levelTimestampKey = '__meta_level_updated_at';

  Future<Box> _open() async {
    final name = UserDataScope.boxName('slideProgress');
    if (_box == null || _boxName != name) {
      final generation = UserDataScope.generation;
      final box = await Hive.openBox(name);
      if (generation != UserDataScope.generation ||
          name != UserDataScope.boxName('slideProgress')) {
        return _open();
      }
      _box = box;
      _boxName = name;
    }
    return _box!;
  }

  Future<void> activateUser() async {
    _box = null;
    _boxName = null;
    await _open();
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
    final generation = UserDataScope.generation;
    final boxName = UserDataScope.boxName('slideProgress');
    final b = await _open();
    if (generation != UserDataScope.generation ||
        boxName != UserDataScope.boxName('slideProgress') ||
        _boxName != boxName) {
      return;
    }
    final key = _key(day, prefix);
    final cur = (b.get(key) as int?) ?? 0;
    final v = pageIndex + 1;
    var changed = false;
    if (v > cur) {
      await b.put(key, v.clamp(0, total));
      changed = true;
    }
    if (prefix.isEmpty) {
      await b.put('lastDay', day);
      await b.put(_lastDayTimestampKey, DateTime.now().millisecondsSinceEpoch);
      changed = true;
    }
    if (changed) ProgressSyncService.instance.scheduleSync();
  }

  int? get lastDay => _box?.get('lastDay') as int?;

  /// 전역 학습 난이도 (baby/standard/fast)
  String get level => (_box?.get('level') as String?) ?? 'standard';

  Future<void> setLevel(String v) async {
    if (!const {'baby', 'standard', 'fast'}.contains(v)) return;
    final generation = UserDataScope.generation;
    final boxName = UserDataScope.boxName('slideProgress');
    final b = await _open();
    if (generation != UserDataScope.generation ||
        boxName != UserDataScope.boxName('slideProgress') ||
        _boxName != boxName) {
      return;
    }
    await b.put('level', v);
    await b.put(_levelTimestampKey, DateTime.now().millisecondsSinceEpoch);
    ProgressSyncService.instance.scheduleSync();
  }
}
