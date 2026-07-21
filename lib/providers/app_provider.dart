import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import '../services/exam_track.dart';
import '../services/study_data.dart';
import '../services/qnet_catalog.dart';
import '../services/qnet_schedule_service.dart';
import '../services/schedule_alerts.dart';
import '../services/exam_registration.dart';
import '../services/notification_service.dart';

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
  String themePaletteId = 'indigo';
  String selectedTutorId = 'volt';
  bool notificationsEnabled = true; // 🔔 시험 일정·학습 리마인드 알림 on/off
  bool dailyReminderEnabled = true;
  int dailyReminderHour = 9;
  bool reduceMotion = false; // ♿ 애니메이션 감소(접근성)
  double textScaleFactor = 1.0; // ♿ 앱 내 글자 크기 배율(접근성)
  String? lastAutoBackupAt; // 💾 마지막 자동 백업 시각(ISO8601)
  bool examInProgress = false; // 🔒 실전모드 진행 중 여부(런타임 전용, 저장 안 함)

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
    await ExamRegistrationStore.instance.init();
    _load();
  }

  void _load() {
    exams =
        _examBox.values
            .map((e) => Exam.fromMap(Map<dynamic, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.examDate.compareTo(b.examDate));
    sessions =
        _sessionBox.values
            .map((e) => StudySession.fromMap(Map<dynamic, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    notes =
        _noteBox.values
            .map((e) => WrongNote.fromMap(Map<dynamic, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    quizResults =
        _quizBox.values.map((e) => Map<String, dynamic>.from(e)).toList()..sort(
          (a, b) => (b['date'] as String).compareTo(a['date'] as String),
        );
    dailyGoalMinutes = (_settingsBox.get('dailyGoal') as int?) ?? 120;
    weeklyGoalMinutes = (_settingsBox.get('weeklyGoal') as int?) ?? 600;
    darkMode = (_settingsBox.get('darkMode') as bool?) ?? false;
    themePaletteId = (_settingsBox.get('themePalette') as String?) ?? 'indigo';
    selectedTutorId = (_settingsBox.get('selectedTutor') as String?) ?? 'volt';
    notificationsEnabled =
        (_settingsBox.get('notificationsEnabled') as bool?) ?? true;
    dailyReminderEnabled =
        (_settingsBox.get('dailyReminderEnabled') as bool?) ?? true;
    dailyReminderHour = (_settingsBox.get('dailyReminderHour') as int?) ?? 9;
    reduceMotion = (_settingsBox.get('reduceMotion') as bool?) ?? false;
    textScaleFactor = (_settingsBox.get('textScaleFactor') as double?) ?? 1.0;
    lastAutoBackupAt = _settingsBox.get('lastAutoBackupAt') as String?;
    shieldCount = (_settingsBox.get('shieldCount') as int?) ?? 0;
    onboarded = (_settingsBox.get('onboarded_v1') as bool?) ?? false;
    selectedTrackId = _settingsBox.get('selectedTrack') as String?;
    if (selectedTrackId != null) {
      StudyData.instance.setTrack(trackById(selectedTrackId!));
    }
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
    final sids = sessions
        .where((s) => s.examId == id)
        .map((s) => s.id)
        .toList();
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
    Map<String, int> subjectTotal = const {},
    Map<String, int> subjectCorrect = const {},
  }) async {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    await _quizBox.put(id, {
      'id': id,
      'title': title,
      'total': total,
      'correct': correct,
      'date': now.toIso8601String(),
      // 과목별 정답/문항 수 (약점 진단용)
      'subjectTotal': Map<String, int>.from(subjectTotal),
      'subjectCorrect': Map<String, int>.from(subjectCorrect),
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

  Future<void> setThemePalette(String id) async {
    themePaletteId = id;
    await _settingsBox.put('themePalette', id);
    notifyListeners();
  }

  Future<void> setSelectedTutor(String id) async {
    const available = {'soyeon', 'harin', 'jiyoon'};
    if (!available.contains(id)) return;
    selectedTutorId = id;
    await _settingsBox.put('selectedTutor', id);
    notifyListeners();
  }

  // ===== 🔔 알림 설정 =====
  Future<void> setNotificationsEnabled(bool v) async {
    notificationsEnabled = v;
    await _settingsBox.put('notificationsEnabled', v);
    if (v) {
      await NotificationService.instance.scheduleExamAlerts(alerts);
      if (dailyReminderEnabled) {
        await NotificationService.instance.scheduleDailyReminder(
          hour: dailyReminderHour,
        );
      }
    } else {
      await NotificationService.instance.cancelAll();
    }
    notifyListeners();
  }

  Future<void> setDailyReminderEnabled(bool v) async {
    dailyReminderEnabled = v;
    await _settingsBox.put('dailyReminderEnabled', v);
    if (v && notificationsEnabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: dailyReminderHour,
      );
    } else {
      await NotificationService.instance.cancelDailyReminder();
    }
    notifyListeners();
  }

  Future<void> setDailyReminderHour(int hour) async {
    dailyReminderHour = hour;
    await _settingsBox.put('dailyReminderHour', hour);
    if (dailyReminderEnabled && notificationsEnabled) {
      await NotificationService.instance.scheduleDailyReminder(hour: hour);
    }
    notifyListeners();
  }

  // ===== 🔒 실전모드 상태 (Q65: AI튜터 접근 제한 판단용) =====
  void setExamInProgress(bool v) {
    if (examInProgress == v) return;
    examInProgress = v;
    notifyListeners();
  }

  // ===== ♿ 접근성 설정 =====
  Future<void> setReduceMotion(bool v) async {
    reduceMotion = v;
    await _settingsBox.put('reduceMotion', v);
    notifyListeners();
  }

  Future<void> setTextScaleFactor(double v) async {
    textScaleFactor = v.clamp(0.8, 1.6);
    await _settingsBox.put('textScaleFactor', textScaleFactor);
    notifyListeners();
  }

  // ===== 💾 자동 백업 시각 기록 =====
  Future<void> markAutoBackupNow() async {
    lastAutoBackupAt = DateTime.now().toIso8601String();
    await _settingsBox.put('lastAutoBackupAt', lastAutoBackupAt);
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
      await addSession(
        StudySession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          examId: timerExamId ?? '',
          date: DateTime.now(),
          minutes: minutes,
          subject: '타이머 학습',
        ),
      );
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
        .where(
          (s) =>
              s.date.year == day.year &&
              s.date.month == day.month &&
              s.date.day == day.day,
        )
        .fold(0, (sum, s) => sum + s.minutes);
  }

  int get todayMinutes => minutesOnDate(DateTime.now());

  int get weekMinutes {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
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

  // ===== 🎯 시험 종목 선택 =====
  /// 선택된 종목 id. null 이면 아직 종목 미선택(진입 화면 표시).
  String? selectedTrackId;

  ExamTrack? get selectedTrack =>
      selectedTrackId == null ? null : trackById(selectedTrackId!);

  /// 종목 선택/전환: StudyData 캐시를 리셋하고 화면을 갱신한다.
  Future<void> selectTrack(String trackId) async {
    selectedTrackId = trackId;
    StudyData.instance.setTrack(trackById(trackId));
    await _settingsBox.put('selectedTrack', trackId);
    notifyListeners();
  }

  /// 종목 선택 화면으로 되돌리기(다른 시험 고르기).
  Future<void> clearTrack() async {
    selectedTrackId = null;
    await _settingsBox.delete('selectedTrack');
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

  int minutesForExam(String examId) => sessions
      .where((s) => s.examId == examId)
      .fold(0, (sum, s) => sum + s.minutes);

  // ===== XP & 레벨 (마법사 성장 시스템) =====
  /// 학습 1분 = 2XP, 정답 1개 = 5XP
  int get xp {
    final quizXp = quizResults.fold<int>(
      0,
      (s, r) => s + ((r['correct'] as int?) ?? 0) * 5,
    );
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
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final minuteXp = weekMinutes * 2;
    final quizXp = quizResults
        .where((r) {
          final d = DateTime.tryParse(r['date'] as String? ?? '');
          return d != null && !d.isBefore(monday);
        })
        .fold<int>(0, (s, r) => s + ((r['correct'] as int?) ?? 0) * 5);
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

  // ===== 📊 약점 진단 / 회독 트래커 =====

  /// 누적 푼 문제 수(전체 세션 합)
  int get lifetimeSolved =>
      quizResults.fold<int>(0, (s, r) => s + ((r['total'] as int?) ?? 0));

  /// 누적 맞힌 문제 수
  int get lifetimeCorrect =>
      quizResults.fold<int>(0, (s, r) => s + ((r['correct'] as int?) ?? 0));

  /// 전체 평균 정답률(%)
  int get overallAccuracy => lifetimeSolved == 0
      ? 0
      : (lifetimeCorrect * 100 / lifetimeSolved).round();

  /// 완료한 모의고사(세션) 수
  int get completedQuizSessions => quizResults.length;

  /// 회독 수 — 누적 푼 문제 수를 기준(문항수)으로 추정.
  /// 종목 문제은행 전체 문항 수 [bankSize]로 나눈 몫.
  int reviewRounds(int bankSize) {
    if (bankSize <= 0) return 0;
    return lifetimeSolved ~/ bankSize;
  }

  /// 현재 회독 진행률(0.0~1.0) — 다음 회독까지 얼마나 남았는지.
  double reviewRoundProgress(int bankSize) {
    if (bankSize <= 0) return 0;
    return (lifetimeSolved % bankSize) / bankSize;
  }

  /// 과목별 누적 정답률 리스트 — 약점 진단용.
  /// 반환: [{subject, total, correct, accuracy}] 정답률 오름차순(약한 과목 먼저)
  List<Map<String, dynamic>> subjectAnalysis() {
    final totals = <String, int>{};
    final corrects = <String, int>{};
    for (final r in quizResults) {
      final st = r['subjectTotal'];
      final sc = r['subjectCorrect'];
      if (st is Map) {
        st.forEach((k, v) {
          final key = k.toString();
          totals[key] = (totals[key] ?? 0) + ((v as num?)?.toInt() ?? 0);
        });
      }
      if (sc is Map) {
        sc.forEach((k, v) {
          final key = k.toString();
          corrects[key] = (corrects[key] ?? 0) + ((v as num?)?.toInt() ?? 0);
        });
      }
    }
    final list = <Map<String, dynamic>>[];
    for (final subject in totals.keys) {
      final t = totals[subject] ?? 0;
      final c = corrects[subject] ?? 0;
      if (t == 0 || subject.trim().isEmpty) continue;
      list.add({
        'subject': subject,
        'total': t,
        'correct': c,
        'accuracy': (c * 100 / t).round(),
      });
    }
    list.sort((a, b) => (a['accuracy'] as int).compareTo(b['accuracy'] as int));
    return list;
  }

  // ===== 🌐 Q-Net 실시간 시험일정 연동 =====
  /// 현재 화면에서 보고 있는 종목(카탈로그) id.
  String _catalogId = kQnetCatalog.first.id;
  String get catalogId => _catalogId;
  CatalogItem get catalogItem => catalogItemById(_catalogId);

  List<QnetExamRound> qnetRounds = [];
  List<ScheduleAlert> alerts = [];
  bool loadingSchedule = false;
  String? scheduleError;
  DateTime? scheduleFetchedAt;

  /// 종목 전환 후 일정 새로고침.
  Future<void> selectCatalog(String id, {bool refresh = true}) async {
    _catalogId = id;
    await _settingsBox.put('catalogId', id);
    notifyListeners();
    if (refresh) await refreshSchedule();
  }

  /// 저장된 카탈로그 선택 복원 + 최초 일정 로드.
  Future<void> initSchedule() async {
    _catalogId =
        (_settingsBox.get('catalogId') as String?) ?? kQnetCatalog.first.id;
    await refreshSchedule();
  }

  /// 실시간 시험일정 크롤링 후 알림 재생성.
  Future<void> refreshSchedule({bool force = false}) async {
    final item = catalogItem;
    loadingSchedule = true;
    scheduleError = null;
    notifyListeners();

    if (!item.isQnet || item.jmCd == null) {
      // 학교 교과 등 크롤링 미지원 종목
      qnetRounds = [];
      alerts = [];
      loadingSchedule = false;
      scheduleError = '이 종목은 실시간 시험일정 연동을 지원하지 않아요.';
      notifyListeners();
      return;
    }

    try {
      final rounds = await QnetScheduleService.instance.fetchSchedule(
        item.jmCd!,
        seriesCd: item.seriesCd,
        catalogId: item.id,
        forceRefresh: force,
      );
      qnetRounds = rounds
        ..sort((a, b) {
          final ad = a.anchorDate;
          final bd = b.anchorDate;
          if (ad == null || bd == null) return 0;
          return ad.compareTo(bd);
        });
      alerts = ScheduleAlertEngine.instance.buildAlerts(item.name, rounds);
      scheduleFetchedAt = DateTime.now();
      if (rounds.isEmpty) {
        scheduleError = '시험일정을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
      }
      // 🔔 앱을 꺼둬도 시험 일정을 놓치지 않도록 실제 기기 알림을 예약한다.
      if (notificationsEnabled) {
        unawaited(NotificationService.instance.scheduleExamAlerts(alerts));
      }
    } catch (e) {
      scheduleError = '네트워크 오류로 일정을 불러오지 못했어요.';
    } finally {
      loadingSchedule = false;
      notifyListeners();
    }
  }

  // ===== 🎯 응시 등록 / 가답안 =====
  List<ExamRegistration> get registrations =>
      ExamRegistrationStore.instance.all();

  ExamRegistration? registrationFor(
    String jmCd,
    String roundLabel,
    ExamPhase phase,
  ) {
    final id = ExamRegistration.makeId(jmCd, roundLabel, phase);
    return ExamRegistrationStore.instance.byId(id);
  }

  Future<void> saveRegistration(ExamRegistration reg) async {
    await ExamRegistrationStore.instance.save(reg);
    notifyListeners();
  }

  Future<void> deleteRegistration(String id) async {
    await ExamRegistrationStore.instance.delete(id);
    notifyListeners();
  }

  /// 홈 화면 요약용: 가장 임박한 활성 알림.
  ScheduleAlert? get topAlert => alerts.isEmpty ? null : alerts.first;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
