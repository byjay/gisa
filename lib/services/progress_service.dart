import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'study_data.dart';

/// 문제 단위 학습 진척 추적 서비스 (상위 자격증 앱 수준)
/// - 문제별 정답/오답 횟수, 마지막 결과, 북마크
/// - 토픽별 정답률 → 약점 분석
/// - AI 맞춤 문제집 (약점 토픽 + 빈출도 가중 추출)
class ProgressService {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  Box? _box; // qid -> {wrong, correct, last, bookmarked, updatedAt}
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    _box = await Hive.openBox('questionProgress');
    _ready = true;
  }

  Map<String, dynamic> _rec(String qid) {
    final raw = _box?.get(qid);
    if (raw == null) return {'wrong': 0, 'correct': 0, 'last': '', 'bookmarked': false};
    return Map<String, dynamic>.from(raw);
  }

  /// 풀이 결과 기록
  Future<void> record(Question q, bool correct) async {
    await _ensure();
    final r = _rec(q.qid);
    if (correct) {
      r['correct'] = (r['correct'] as int? ?? 0) + 1;
    } else {
      r['wrong'] = (r['wrong'] as int? ?? 0) + 1;
    }
    r['last'] = correct ? 'o' : 'x';
    r['subject'] = q.subject;
    r['topic'] = q.topic;
    r['updatedAt'] = DateTime.now().toIso8601String();
    await _box!.put(q.qid, r);
  }

  /// 북마크 토글 — 반환값: 토글 후 상태
  Future<bool> toggleBookmark(Question q) async {
    await _ensure();
    final r = _rec(q.qid);
    final now = !(r['bookmarked'] as bool? ?? false);
    r['bookmarked'] = now;
    r['subject'] = q.subject;
    r['topic'] = q.topic;
    r['updatedAt'] = DateTime.now().toIso8601String();
    await _box!.put(q.qid, r);
    return now;
  }

  Future<bool> isBookmarked(String qid) async {
    await _ensure();
    return _rec(qid)['bookmarked'] as bool? ?? false;
  }

  /// 마지막 결과가 오답인 문제들의 qid 집합
  Future<Set<String>> wrongQids() async {
    await _ensure();
    final out = <String>{};
    for (final key in _box!.keys) {
      final r = _rec(key as String);
      if (r['last'] == 'x') out.add(key);
    }
    return out;
  }

  Future<Set<String>> bookmarkedQids() async {
    await _ensure();
    final out = <String>{};
    for (final key in _box!.keys) {
      final r = _rec(key as String);
      if (r['bookmarked'] == true) out.add(key);
    }
    return out;
  }

  /// qid 집합 → 실제 Question 객체로 복원 (다시 풀기 가능)
  Future<List<Question>> resolveQuestions(Set<String> qids) async {
    if (qids.isEmpty) return [];
    final exams = await StudyData.instance.loadExams();
    final out = <Question>[];
    for (final e in exams) {
      for (final q in e.questions) {
        q.examLabel = e.label;
        if (qids.contains(q.qid)) out.add(q);
      }
    }
    return out;
  }

  /// 토픽별 정답률 통계: subject -> topic -> (correct, total)
  Future<Map<String, Map<String, List<int>>>> topicStats() async {
    await _ensure();
    final out = <String, Map<String, List<int>>>{};
    for (final key in _box!.keys) {
      final r = _rec(key as String);
      final subject = r['subject'] as String? ?? '';
      final topic = r['topic'] as String? ?? '기타';
      if (subject.isEmpty) continue;
      final c = r['correct'] as int? ?? 0;
      final w = r['wrong'] as int? ?? 0;
      if (c + w == 0) continue;
      final bySubject = out.putIfAbsent(subject, () => {});
      final pair = bySubject.putIfAbsent(topic, () => [0, 0]);
      pair[0] += c;
      pair[1] += c + w;
    }
    return out;
  }

  /// 전체 요약: (푼 문제 수, 총 정답, 총 시도, 오답 수, 북마크 수)
  Future<({int solved, int correct, int attempts, int wrong, int bookmarks})>
      summary() async {
    await _ensure();
    var solved = 0, correct = 0, attempts = 0, wrong = 0, bookmarks = 0;
    for (final key in _box!.keys) {
      final r = _rec(key as String);
      final c = r['correct'] as int? ?? 0;
      final w = r['wrong'] as int? ?? 0;
      if (c + w > 0) solved++;
      correct += c;
      attempts += c + w;
      if (r['last'] == 'x') wrong++;
      if (r['bookmarked'] == true) bookmarks++;
    }
    return (
      solved: solved,
      correct: correct,
      attempts: attempts,
      wrong: wrong,
      bookmarks: bookmarks
    );
  }

  /// AI 맞춤 문제집 생성 — 약점 토픽(정답률 낮음) + 빈출도(freqScore) 가중 샘플링
  /// 풀이 이력이 없으면 빈출도 상위에서 추출
  Future<List<Question>> buildSmartSet({int count = 20, String? subject}) async {
    await _ensure();
    final stats = await topicStats();
    // 토픽 정답률 맵
    final accuracy = <String, double>{}; // 'subject|topic' -> 0~1
    stats.forEach((s, topics) {
      topics.forEach((t, pair) {
        if (pair[1] > 0) accuracy['$s|$t'] = pair[0] / pair[1];
      });
    });

    final exams = await StudyData.instance.loadExams();
    final pool = <Question>[];
    for (final e in exams) {
      for (final q in e.questions) {
        if (subject != null && q.subject != subject) continue;
        q.examLabel = e.label;
        pool.add(q);
      }
    }
    if (pool.isEmpty) return [];

    // 가중치: 빈출도(0~100) + 약점 보너스(정답률 낮을수록 최대 +120) + 오답문제 보너스
    final wrongSet = await wrongQids();
    double weight(Question q) {
      var w = q.freqScore + 10;
      final acc = accuracy['${q.subject}|${q.topic}'];
      if (acc != null) w += (1 - acc) * 120;
      if (wrongSet.contains(q.qid)) w += 80;
      return w;
    }

    // 가중 랜덤 샘플링 (중복 문제 제거: 같은 문제 텍스트 앞 40자 기준)
    final rng = Random();
    final weighted = pool.map((q) => (q, weight(q))).toList();
    final picked = <Question>[];
    final seen = <String>{};
    while (picked.length < count && weighted.isNotEmpty) {
      final total = weighted.fold<double>(0, (a, b) => a + b.$2);
      var roll = rng.nextDouble() * total;
      var idx = 0;
      for (var i = 0; i < weighted.length; i++) {
        roll -= weighted[i].$2;
        if (roll <= 0) {
          idx = i;
          break;
        }
      }
      final q = weighted.removeAt(idx).$1;
      final sig = q.question.length > 40 ? q.question.substring(0, 40) : q.question;
      if (seen.add(sig)) picked.add(q);
    }
    return picked;
  }

  /// 약점 토픽 상위 N개: (subject, topic, 정답률%, 시도수)
  Future<List<(String, String, int, int)>> weakTopics({int limit = 8}) async {
    final stats = await topicStats();
    final rows = <(String, String, int, int)>[];
    stats.forEach((s, topics) {
      topics.forEach((t, pair) {
        if (pair[1] >= 2) {
          rows.add((s, t, (pair[0] * 100 / pair[1]).round(), pair[1]));
        }
      });
    });
    rows.sort((a, b) => a.$3.compareTo(b.$3));
    return rows.take(limit).toList();
  }
}
