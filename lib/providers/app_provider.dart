import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

class AppProvider extends ChangeNotifier {
  late Box _examBox;
  late Box _sessionBox;
  late Box _noteBox;
  late Box _settingsBox;
  late Box _quizBox;

  List<Exam> exams = [];
  List<StudySession> sessions = [];
  List<WrongNote> notes = [];
  List<Map<String, dynamic>> quizResults = [];

  // Goal settings
  int dailyGoalMinutes = 120;
  bool darkMode = false;
  int weeklyGoalMinutes = 600;

  // Timer state
  bool timerRunning = false;
  DateTime? timerStart;
  int elapsedSeconds = 0;
  Timer? _ticker;
  String? timerExamId;

  Future<void> init() async {
    await Hive.initFlutter();
    _examBox = await Hive.openBox('exams');
    _sessionBox = await Hive.openBox('sessions');
    _noteBox = await Hive.openBox('wrongNotes');
    _settingsBox = await Hive.openBox('settings');
    _quizBox = await Hive.openBox('quizResults');
    _load();
  }

  void _load() {
    exams = _examBox.values
        .map((e) => Exam.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.examDate.compareTo(b.examDate));
    sessions = _sessionBox.values
        .map((e) => StudySession.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    notes = _noteBox.values
        .map((e) => WrongNote.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    quizResults = _quizBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) =>
          (b['date'] as String).compareTo(a['date'] as String));
    dailyGoalMinutes = (_settingsBox.get('dailyGoal') as int?) ?? 120;
    weeklyGoalMinutes = (_settingsBox.get('weeklyGoal') as int?) ?? 600;
    darkMode = (_settingsBox.get('darkMode') as bool?) ?? false;
    shieldCount = (_settingsBox.get('shieldCount') as int?) ?? 0;
    onboarded = (_settingsBox.get('onboarded_v1') as bool?) ?? false;
    _autoConsumeShield();
    notifyListeners();
  }

  // ===== Exams =====
  Future<void> addExam(Exam exam) async {
    await _examBox.put(exam.id, exam.toMap());
    _load();
  }

  Future<void> updateExam(Exam exam) async {
    await _examBox.put(exam.id, exam.toMap());
    _load();
  }

  Future<void> deleteExam(String id) async {
    await _examBox.delete(id);
    // cascade delete sessions and notes
    final sids = sessions.where((s) => s.examId == id).map((s) => s.id).toList();
    for (final sid in sids) {
      await _sessionBox.delete(sid);
    }
    final nids = notes.where((n) => n.examId == id).map((n) => n.id).toList();
    for (final nid in nids) {
      await _noteBox.delete(nid);
    }
    _load();
  }

  Exam? examById(String? id) {
    if (id == null) return null;
    try {
      return exams.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // ===== Sessions =====
  Future<void> addSession(StudySession s) async {
    await _sessionBox.put(s.id, s.toMap());
    _load();
  }

  Future<void> deleteSession(String id) async {
    await _sessionBox.delete(id);
    _load();
  }

  // ===== Wrong Notes =====
  Future<void> addNote(WrongNote n) async {
    await _noteBox.put(n.id, n.toMap());
    _load();
  }

  Future<void> updateNote(WrongNote n) async {
    await _noteBox.put(n.id, n.toMap());
    _load();
  }

  Future<void> deleteNote(String id) async {
    await _noteBox.delete(id);
    _load();
  }

  // ===== Quiz Results (CBT 학습이력) =====
  Future<void> addQuizResult({
    required String title,
    required int total,
    required int correct,
    List<String> wrongQuestions = const [],
  }) async {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    await _quizBox.put(id, {
      'id': id,
      'title': title,
      'total': total,
      'correct': correct,
      'date': now.toIso8601String(),
    });
    // 오답은 오답노트에 자동 등록 (최대 20개)
    for (var i = 0; i < wrongQuestions.length && i < 20; i++) {
      final nid = '${id}_w$i';
      await _noteBox.put(nid, {
        'id': nid,
        'examId': '',
        'question': wrongQuestions[i],
        'answer': '',
        'memo': 'CBT 자동등록: $title',
        'mastered': false,
        'createdAt': now.toIso8601String(),
      });
    }
    _load();
  }

  Future<void> deleteQuizResult(String id) async {
    await _quizBox.delete(id);
    _load();
  }

  // ===== Theme =====
  Future<void> toggleDarkMode() async {
    darkMode = !darkMode;
    await _settingsBox.put('darkMode', darkMode);
    notifyListeners();
  }

  // ===== Goals =====
  Future<void> setGoals({required int daily, required int weekly}) async {
    dailyGoalMinutes = daily;
    weeklyGoalMinutes = weekly;
    await _settingsBox.put('dailyGoal', daily);
    await _settingsBox.put('weeklyGoal', weekly);
    notifyListeners();
  }

  // ===== Timer =====
  void startTimer(String? examId) {
    timerRunning = true;
    timerStart = DateTime.now();
    timerExamId = examId;
    elapsedSeconds = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<int> stopTimer() async {
    _ticker?.cancel();
    _ticker = null;
    timerRunning = false;
    final minutes = (elapsedSeconds / 60).ceil();
    if (minutes > 0) {
      await addSession(StudySession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        examId: timerExamId ?? '',
        date: DateTime.now(),
        minutes: minutes,
        subject: '타이머 학습',
      ));
    }
    final result = elapsedSeconds;
    elapsedSeconds = 0;
    timerExamId = null;
    notifyListeners();
    return result;
  }

  void cancelTimer() {
    _ticker?.cancel();
    _ticker = null;
    timerRunning = false;
    elapsedSeconds = 0;
    timerExamId = null;
    notifyListeners();
  }

  // ===== Stats =====
  int minutesOnDate(DateTime day) {
    return sessions
        .where((s) =>
            s.date.year == day.year &&
            s.date.month == day.month &&
            s.date.day == day.day)
        .fold(0, (sum, s) => sum + s.minutes);
  }

  int get todayMinutes => minutesOnDate(DateTime.now());

  int get weekMinutes {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    int total = 0;
    for (int i = 0; i < 7; i++) {
      total += minutesOnDate(monday.add(Duration(days: i)));
    }
    return total;
  }

  int get totalMinutes => sessions.fold(0, (sum, s) => sum + s.minutes);

  /// Streak: consecutive days with study up to today (or yesterday).
  /// 🛡️ 마법 방패로 보호된 날짜(shieldUsedDates)는 학습한 날로 간주.
  int get streak {
    int count = 0;
    var day = DateTime.now();
    if (!_countsForStreak(day)) {
      day = day.subtract(const Duration(days: 1));
    }
    while (_countsForStreak(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  bool _countsForStreak(DateTime day) =>
      minutesOnDate(day) > 0 || _shieldUsedDates.contains(_dayKey(day));

  // ===== 🛡️ 스트릭 보호권 (마법 방패) =====
  /// Duolingo streak-freeze 방식: 하루 건너뛰면 방패가 자동 소모되어 스트릭 유지.
  int shieldCount = 0;
  static const int maxShields = 2;

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<String> get _shieldUsedDates =>
      List<String>.from(_settingsBox.get('shieldUsedDates') as List? ?? []);

  /// 오늘의 3대 마법 미션 올클리어 여부 (daily_mission_card와 단일 공식)
  bool get todayMissionsAllDone =>
      todayMinutes >= 30 && todayQuizSolved >= 10 && todayQuizCorrect >= 5;

  /// 미션 올클리어 시 방패 1개 지급 (하루 1회, 최대 2개). 지급되면 true.
  Future<bool> maybeEarnShield() async {
    if (!todayMissionsAllDone || shieldCount >= maxShields) return false;
    final today = _dayKey(DateTime.now());
    if ((_settingsBox.get('shieldLastEarnDay') as String?) == today) {
      return false;
    }
    shieldCount++;
    await _settingsBox.put('shieldCount', shieldCount);
    await _settingsBox.put('shieldLastEarnDay', today);
    notifyListeners();
    return true;
  }

  /// 앱 시작 시 자동 점검: 어제를 건너뛪고 그전까지 스트릭이 있었다면 방패 소모.
  void _autoConsumeShield() {
    if (shieldCount <= 0) return;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yKey = _dayKey(yesterday);
    if (minutesOnDate(yesterday) > 0) return; // 어제 학습함 — 불필요
    final used = _shieldUsedDates;
    if (used.contains(yKey)) return; // 이미 보호됨
    // 그전날까지 스트릭이 있었는지 확인 (보호할 가치가 있는지)
    final dayBefore = yesterday.subtract(const Duration(days: 1));
    if (!_countsForStreak(dayBefore)) return;
    used.add(yKey);
    shieldCount--;
    _settingsBox.put('shieldUsedDates', used);
    _settingsBox.put('shieldCount', shieldCount);
    shieldJustConsumed = true; // UI에서 1회성 안내용
  }

  /// 방패가 방금 소모됐음을 UI에 1회 알리기 위한 플래그
  bool shieldJustConsumed = false;

  // ===== ✨ 온보딩 =====
  bool onboarded = false;

  Future<void> completeOnboarding() async {
    onboarded = true;
    await _settingsBox.put('onboarded_v1', true);
    notifyListeners();
  }

  /// Last N days minutes for chart (oldest first)
  List<int> lastNDaysMinutes(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      final day = now.subtract(Duration(days: n - 1 - i));
      return minutesOnDate(day);
    });
  }

  int minutesForExam(String examId) =>
      sessions.where((s) => s.examId == examId).fold(0, (sum, s) => sum + s.minutes);

  // ===== XP & 레벨 (마법사 성장 시스템) =====
  /// 학습 1분 = 2XP, 정답 1개 = 5XP
  int get xp {
    final quizXp = quizResults.fold<int>(
        0, (s, r) => s + ((r['correct'] as int?) ?? 0) * 5);
    return totalMinutes * 2 + quizXp;
  }

  /// 레벨 n 도달에 필요한 누적 XP = (n-1)^2 * 120
  int xpForLevel(int level) => (level - 1) * (level - 1) * 120;

  int get level {
    var l = 1;
    while (xp >= xpForLevel(l + 1)) {
      l++;
    }
    return l;
  }

  /// 현재 레벨 내 진행률 (0.0 ~ 1.0)
  double get levelProgress {
    final cur = xpForLevel(level);
    final next = xpForLevel(level + 1);
    if (next == cur) return 0;
    return ((xp - cur) / (next - cur)).clamp(0.0, 1.0);
  }

  int get xpToNextLevel => xpForLevel(level + 1) - xp;

  String get levelTitle {
    final l = level;
    if (l >= 15) return '전설의 대마법사';
    if (l >= 10) return '대마법사';
    if (l >= 7) return '상급 마법사';
    if (l >= 5) return '정식 마법사';
    if (l >= 3) return '수습 마법사';
    return '견습 마법사';
  }

  /// 🏆 이번 주(월~지금) 획득 XP — 위클리 리그 순위 산정용
  int get weekXp {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final minuteXp = weekMinutes * 2;
    final quizXp = quizResults.where((r) {
      final d = DateTime.tryParse(r['date'] as String? ?? '');
      return d != null && !d.isBefore(monday);
    }).fold<int>(0, (s, r) => s + ((r['correct'] as int?) ?? 0) * 5);
    return minuteXp + quizXp;
  }

  /// 오늘 푼 문제 수 (퀴즈 결과 기준)
  int get todayQuizSolved {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return quizResults
        .where((r) => (r['date'] as String).startsWith(today))
        .fold<int>(0, (s, r) => s + ((r['total'] as int?) ?? 0));
  }

  /// 오늘 맞힌 문제 수
  int get todayQuizCorrect {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return quizResults
        .where((r) => (r['date'] as String).startsWith(today))
        .fold<int>(0, (s, r) => s + ((r['correct'] as int?) ?? 0));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
