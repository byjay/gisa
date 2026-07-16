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

  /// 간격반복(Leitner) 박스별 다음 복습 간격(일) — box 0~4
  static const List<int> _srsIntervalDays = [0, 1, 3, 7, 16];

  /// 풀이 결과 기록 + 간격반복 스케줄링
  /// - 맞히면 박스 +1(간격 늘어남), 틀리면 박스 0으로 초기화(내일 다시 만남)
  /// - "봤던 문제 또 보면 바로 정답" 훈련의 핵심: 틀린 문제는 반드시 며칠 안에 재등장
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
    // 시각적 10회 반복 합격: 문제를 만날 때마다 reps +1 (맞든 틀리든 노출 카운트)
    r['reps'] = (r['reps'] as int? ?? 0) + 1;
    // 연속 정답(streak): 틀리면 0으로 초기화 → "확실히 외운" 판정 기준
    r['streak'] =
        correct ? ((r['streak'] as int? ?? 0) + 1) : 0;
    final box = correct
        ? ((r['box'] as int? ?? 0) + 1).clamp(0, _srsIntervalDays.length - 1)
        : 0;
    r['box'] = box;
    r['nextDue'] = DateTime.now()
        .add(Duration(days: _srsIntervalDays[box]))
        .toIso8601String();
    r['updatedAt'] = DateTime.now().toIso8601String();
    await _box!.put(q.qid, r);
  }

  /// 시각적 반복 암기 전용: 카드를 1회 "봤다"고 기록(정답 여부 없이 노출만).
  /// 플래시카드/암기모드에서 카드를 넘길 때 호출 → reps 증가.
  Future<void> recordExposure(String qid,
      {String subject = '', String topic = ''}) async {
    await _ensure();
    final r = _rec(qid);
    r['reps'] = (r['reps'] as int? ?? 0) + 1;
    if (subject.isNotEmpty) r['subject'] = subject;
    if (topic.isNotEmpty) r['topic'] = topic;
    r['updatedAt'] = DateTime.now().toIso8601String();
    await _box!.put(qid, r);
  }

  /// 특정 문제의 반복 노출 횟수(reps) — 10회 반복 목표 진행도.
  Future<int> repsFor(String qid) async {
    await _ensure();
    return (_rec(qid)['reps'] as int? ?? 0);
  }

  /// 특정 문제의 누적 오답 횟수 — 오답노트 강제 노출 판단용.
  Future<int> wrongCountFor(String qid) async {
    await _ensure();
    return (_rec(qid)['wrong'] as int? ?? 0);
  }

  /// 목표 반복(기본 10회)까지의 전체 진행 요약.
  /// - total: 전체 대상 카드 수, mastered: reps>=goal 달성 수, totalReps: 누적 노출
  ({int total, int mastered, int totalReps}) repetitionSummary(
      Iterable<String> qids,
      {int goal = 10}) {
    int total = 0, mastered = 0, totalReps = 0;
    for (final qid in qids) {
      total++;
      final reps = (_rec(qid)['reps'] as int? ?? 0);
      totalReps += reps;
      if (reps >= goal) mastered++;
    }
    return (total: total, mastered: mastered, totalReps: totalReps);
  }

  /// 오답 원인 분류 — 사용자가 "왜 틀렸는지" 선택하는 표준 태그.
  /// (교수·튜터 관점의 표준 오답 유형)
  static const List<String> wrongReasons = [
    '개념 부족',
    '계산 실수',
    '문제 잘못 읽음',
    '함정·헷갈림',
    '공식 암기 안됨',
    '시간 부족·찍음',
  ];

  /// 오답 원인을 기록한다. (틀린 직후 사용자가 선택)
  /// - 문제별 원인 히스토그램 [reasons] 에 누적
  /// - 마지막 원인 [lastReason] 저장
  Future<void> recordWrongReason(Question q, String reason) async {
    await _ensure();
    final r = _rec(q.qid);
    final rawReasons = r['reasons'];
    final reasons = <String, int>{};
    if (rawReasons is Map) {
      rawReasons.forEach((k, v) =>
          reasons[k.toString()] = (v as num?)?.toInt() ?? 0);
    }
    reasons[reason] = (reasons[reason] ?? 0) + 1;
    r['reasons'] = reasons;
    r['lastReason'] = reason;
    r['subject'] = q.subject;
    r['topic'] = q.topic;
    r['updatedAt'] = DateTime.now().toIso8601String();
    await _box!.put(q.qid, r);
  }

  /// 오답 원인별 전체 집계 — {원인: 횟수} (약점 진단·집중 방안용)
  Future<Map<String, int>> wrongReasonStats() async {
    await _ensure();
    final out = <String, int>{};
    for (final key in _box!.keys) {
      final r = _rec(key as String);
      final raw = r['reasons'];
      if (raw is Map) {
        raw.forEach((k, v) =>
            out[k.toString()] = (out[k.toString()] ?? 0) + ((v as num?)?.toInt() ?? 0));
      }
    }
    return out;
  }

  /// 자주 틀리는 문제 랭킹 — wrong 횟수 내림차순.
  /// 반환: [(qid, wrong, correct, subject, topic, lastReason)]
  /// [onlyUnmastered] 이면 마지막 결과가 오답이거나 아직 완전 정답 아닌 것만.
  Future<List<({
    String qid,
    int wrong,
    int correct,
    String subject,
    String topic,
    String? lastReason,
  })>> frequentlyWrong({int limit = 100, bool onlyUnmastered = false}) async {
    await _ensure();
    final rows = <({
      String qid,
      int wrong,
      int correct,
      String subject,
      String topic,
      String? lastReason,
    })>[];
    for (final key in _box!.keys) {
      final r = _rec(key as String);
      final w = r['wrong'] as int? ?? 0;
      if (w == 0) continue;
      if (onlyUnmastered && r['last'] == 'o' &&
          (r['box'] as int? ?? 0) >= _srsIntervalDays.length - 1) {
        continue;
      }
      rows.add((
        qid: key,
        wrong: w,
        correct: r['correct'] as int? ?? 0,
        subject: r['subject'] as String? ?? '',
        topic: r['topic'] as String? ?? '기타',
        lastReason: r['lastReason'] as String?,
      ));
    }
    rows.sort((a, b) => b.wrong.compareTo(a.wrong));
    return rows.take(limit).toList();
  }

  /// 특정 원인으로 틀린 문제 qid 집합 (원인별 집중 풀기용)
  Future<Set<String>> qidsByReason(String reason) async {
    await _ensure();
    final out = <String>{};
    for (final key in _box!.keys) {
      final r = _rec(key as String);
      final raw = r['reasons'];
      if (raw is Map && (raw[reason] as num? ?? 0).toInt() > 0) {
        out.add(key);
      }
    }
    return out;
  }

  /// 이 문제를 이전에 만난 적 있는지 조회 (문제풀이 화면 상단 "N번째 만남" 배너용)
  /// null이면 첫 만남
  Future<({int seenCount, String? lastResult, int box})?> historyFor(
      String qid) async {
    await _ensure();
    final raw = _box!.get(qid);
    if (raw == null) return null;
    final r = Map<String, dynamic>.from(raw);
    final seen = (r['correct'] as int? ?? 0) + (r['wrong'] as int? ?? 0);
    if (seen == 0) return null;
    return (
      seenCount: seen,
      lastResult: r['last'] as String?,
      box: r['box'] as int? ?? 0,
    );
  }

  /// 오늘 복습이 필요한 문제(간격반복 due) qid 집합 — box 4(장기기억 완성) 제외
  Future<Set<String>> dueReviewQids() async {
    await _ensure();
    final now = DateTime.now();
    final out = <String>{};
    for (final key in _box!.keys) {
      final r = _rec(key as String);
      final due = r['nextDue'] as String?;
      if (due == null) continue;
      final box = r['box'] as int? ?? 0;
      if (box >= _srsIntervalDays.length - 1) continue; // 완전 마스터는 급하지 않음
      final dueDate = DateTime.tryParse(due);
      if (dueDate == null) continue;
      if (!dueDate.isAfter(now)) out.add(key);
    }
    return out;
  }

  Future<int> dueReviewCount() async => (await dueReviewQids()).length;

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
