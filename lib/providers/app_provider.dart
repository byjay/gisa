import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
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
import '../services/secure_box_service.dart';
import '../services/tutor_persona.dart' show kTutorPersonas;

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

  // 관리자 기본 정책. 잠금 해제 여부는 저장하지 않고 설정값만 사용자별로 보관한다.
  // [P2-B/S3] 평문 상수 비교 대신 SHA-256 해시를 비교한다. 이 앱의 위협
  // 모델(로컬 기능 잠금, 원격 공격 대상 아님)에서는 평문 비교도 즉각적인
  // 위험은 아니지만, 소스에 평문 비밀번호가 노출되는 것 자체를 없앤다.
  // 원문은 '1234' — sha256('1234')의 16진 다이제스트.
  static const String _initialAdminPasswordHash =
      '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4';
  static const Map<String, bool> defaultFeatureVisibility = {
    'theory': true,
    'practice': true,
    'cbt': true,
    'flashcards': true,
    'aiTutor': true,
  };
  Map<String, bool> featureVisibility = Map<String, bool>.from(
    defaultFeatureVisibility,
  );
  Map<String, Set<String>> hiddenSubjectsByTrack = {};
  bool autoExamTimerEnabled = true;
  int cbtTimeLimitMinutes = 150;
  int cbtQuestionsPerSubject = 20;

  // Timer state
  // ⏱ [P0-A/B1] 경과 시간은 틱 카운트(elapsedSeconds++)가 아니라 시작 시각과
  // 벽시계를 비교해 매 틱 재계산한다. Timer.periodic은 UI 갱신
  // (notifyListeners) 트리거일 뿐, 경과 시간의 진실 원천이 아니다.
  // 백그라운드 진입, 화면 꺼짐, 웹 탭 스로틀링으로 틱이 누락/지연되어도
  // 실제 경과 시간이 정확히 기록되도록 하기 위함.
  bool timerRunning = false;
  DateTime? timerStart;
  int elapsedSeconds = 0;
  Timer? _ticker;
  String? timerExamId;

  /// 테스트에서 시계를 주입할 수 있도록 함수로 분리(fake clock 허용).
  @visibleForTesting
  set debugNow(DateTime Function() fn) => _now = fn;
  DateTime Function() _now = DateTime.now;

  Future<void> init() async {
    await Hive.initFlutter();
    // Q22 로컬 암호화: 민감 데이터(세션/오답노트/시험기록)는 AES 암호화 박스로 연다.
    await SecureBoxService.instance.init();
    _examBox = await Hive.openBox('exams'); // 정적 시험 데이터(비민감) → 평문
    _sessionBox = await SecureBoxService.instance.openSecureBox('sessions');
    _noteBox = await SecureBoxService.instance.openSecureBox('wrongNotes');
    _settingsBox = await Hive.openBox('settings'); // 설정(비민감) → 평문 유지
    _quizBox = await SecureBoxService.instance.openSecureBox('quizResults');
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
    // [P0-B/B9] 백업 복원 등으로 유입된 손상 레코드(date 필드 누락/타입 불일치)가
    // 있어도 비안전 캐스트로 앱이 부팅 크래시하지 않도록 안전 캐스트로 전환.
    quizResults =
        _quizBox.values.map((e) => Map<String, dynamic>.from(e)).toList()..sort(
          (a, b) => ((b['date'] as String?) ?? '').compareTo(
            (a['date'] as String?) ?? '',
          ),
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
    featureVisibility = Map<String, bool>.from(defaultFeatureVisibility);
    final rawFeatures = _settingsBox.get('adminFeatureVisibility');
    if (rawFeatures is Map) {
      rawFeatures.forEach((key, value) {
        if (value is bool) featureVisibility[key.toString()] = value;
      });
    }
    hiddenSubjectsByTrack = {};
    final rawHidden = _settingsBox.get('adminHiddenSubjects');
    if (rawHidden is Map) {
      rawHidden.forEach((key, value) {
        if (value is List) {
          hiddenSubjectsByTrack[key.toString()] = value
              .map((item) => item.toString())
              .toSet();
        }
      });
    }
    autoExamTimerEnabled =
        (_settingsBox.get('adminAutoExamTimer') as bool?) ?? true;
    cbtTimeLimitMinutes =
        (_settingsBox.get('adminCbtTimeLimitMinutes') as int?) ?? 150;
    cbtQuestionsPerSubject =
        (_settingsBox.get('adminCbtQuestionsPerSubject') as int?) ?? 20;
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

  /// [P0-A/B2] 허용 튜터 목록은 이 함수 안에 별도로 하드코딩하지 않고
  /// kTutorPersonas(단일 진실 원천, tutor_persona.dart)에서 파생한다.
  /// 과거 하드코딩 셋 {'soyeon','harin','jiyoon'}에 기본 튜터 'volt'가
  /// 빠져 있어, 다른 튜터로 바꾼 뒤 기본 튜터로 돌아올 수 없는 버그가 있었다.
  Future<void> setSelectedTutor(String id) async {
    if (!kTutorPersonas.any((t) => t.id == id)) return;
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

  // ===== 관리자 정책 설정 =====
  bool verifyAdminPassword(String value) =>
      sha256.convert(utf8.encode(value)).toString() ==
      _initialAdminPasswordHash;

  bool isFeatureEnabled(String feature) => featureVisibility[feature] ?? true;

  List<String> activeSubjectsFor(ExamTrack track) {
    final hidden = hiddenSubjectsByTrack[track.id] ?? const <String>{};
    return track.subjects
        .where((subject) => !hidden.contains(subject))
        .toList();
  }

  bool isSubjectEnabled(String trackId, String subject) =>
      !(hiddenSubjectsByTrack[trackId]?.contains(subject) ?? false);

  Future<void> setFeatureEnabled(String feature, bool enabled) async {
    featureVisibility[feature] = enabled;
    await _settingsBox.put(
      'adminFeatureVisibility',
      Map<String, bool>.from(featureVisibility),
    );
    notifyListeners();
  }

  Future<bool> setSubjectEnabled(
    ExamTrack track,
    String subject,
    bool enabled,
  ) async {
    final hidden = hiddenSubjectsByTrack.putIfAbsent(
      track.id,
      () => <String>{},
    );
    if (enabled) {
      hidden.remove(subject);
    } else {
      final activeCount = activeSubjectsFor(track).length;
      if (activeCount <= 1 && !hidden.contains(subject)) return false;
      hidden.add(subject);
    }
    await _saveHiddenSubjects();
    notifyListeners();
    return true;
  }

  Future<void> _saveHiddenSubjects() async {
    await _settingsBox.put('adminHiddenSubjects', {
      for (final entry in hiddenSubjectsByTrack.entries)
        entry.key: entry.value.toList(),
    });
  }

  Future<void> setAutoExamTimerEnabled(bool enabled) async {
    autoExamTimerEnabled = enabled;
    await _settingsBox.put('adminAutoExamTimer', enabled);
    notifyListeners();
  }

  Future<void> setCbtTimeLimitMinutes(int minutes) async {
    cbtTimeLimitMinutes = minutes.clamp(10, 300);
    await _settingsBox.put('adminCbtTimeLimitMinutes', cbtTimeLimitMinutes);
    notifyListeners();
  }

  Future<void> setCbtQuestionsPerSubject(int count) async {
    cbtQuestionsPerSubject = count.clamp(1, 40);
    await _settingsBox.put(
      'adminCbtQuestionsPerSubject',
      cbtQuestionsPerSubject,
    );
    notifyListeners();
  }

  Future<void> resetAdminSettings() async {
    featureVisibility = Map<String, bool>.from(defaultFeatureVisibility);
    hiddenSubjectsByTrack = {};
    autoExamTimerEnabled = true;
    cbtTimeLimitMinutes = 150;
    cbtQuestionsPerSubject = 20;
    await _settingsBox.deleteAll([
      'adminFeatureVisibility',
      'adminHiddenSubjects',
      'adminAutoExamTimer',
      'adminCbtTimeLimitMinutes',
      'adminCbtQuestionsPerSubject',
    ]);
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
    timerStart = _now();
    timerExamId = examId;
    elapsedSeconds = 0;
    _ticker?.cancel();
    // 틱은 오직 UI 재빌드 트리거. 실제 경과 시간은 시작 시각과 현재
    // 벽시계의 차이로 매번 재계산한다(_liveElapsedSeconds) — B1 수정.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds = _liveElapsedSeconds;
      notifyListeners();
    });
    notifyListeners();
  }

  /// 타이머 시작 시각 기준 실제 경과 시간(초). timerStart가 없으면
  /// 마지막으로 계산된 elapsedSeconds를 그대로 반환한다.
  int get _liveElapsedSeconds {
    if (timerStart == null) return elapsedSeconds;
    return _now().difference(timerStart!).inSeconds;
  }

  Future<int> stopTimer() async {
    _ticker?.cancel();
    _ticker = null;
    timerRunning = false;
    // 정지 시점에도 벽시계로 다시 계산해 마지막 틱 이후의 오차(최대 1s)까지
    // 반영한다.
    elapsedSeconds = _liveElapsedSeconds;
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
    // [P2-A/B5] 동일한 반쪼가리 방지 — 두 값을 하나의 putAll로 묶는다.
    await _settingsBox.putAll({
      'shieldCount': shieldCount,
      'shieldLastEarnDay': today,
    });
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
    // [P2-A/B5] 두 값을 별도 put으로 나열하면 첫 쓰기만 반영되고 두 번째가
    // 실패(또는 프로세스 종료)할 경우 "사용 날짜는 기록됐지만 개수는 그대로"인
    // 상태가 남아 방패가 공짜로 소모 면제되는 결함이 있었다. putAll로 두
    // 값을 하나의 쓰기 오퍼레이션으로 묶어 반쪼가리 상태 발생 확률을 없앤다.
    _settingsBox.putAll({'shieldUsedDates': used, 'shieldCount': shieldCount});
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
  // [P0-B/B9] date 필드가 없는/타입이 다른 레코드가 섞여도 크래시하지 않도록
  // 안전 캐스트로 전환. 해당 레코드는 자연스럽게 필터에서 제외된다.
  int get todayQuizSolved {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return quizResults
        .where((r) => ((r['date'] as String?) ?? '').startsWith(today))
        .fold<int>(0, (s, r) => s + ((r['total'] as int?) ?? 0));
  }

  /// 오늘 맞힌 문제 수
  int get todayQuizCorrect {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return quizResults
        .where((r) => ((r['date'] as String?) ?? '').startsWith(today))
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

  /// [P1-A/R2] 요청 세대 토큰 — 사용자가 종목을 빠르게 전환하면 여러
  /// refreshSchedule 호출이 동시에 진행 중일 수 있다. 늦게 도착한 이전
  /// 요청의 응답이 최신 화면 상태를 덮어쓰지 않도록, 응답을 반영하기
  /// 직전에 자신이 여전히 최신 세대인지 확인한다.
  int _scheduleGen = 0;

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
  ///
  /// [P1-A/R2] 세대 토큰(gen)으로 경합 응답을 방지한다: 이 호출이 시작될 때
  /// 세대를 증가시키고, await 이후 자신이 여전히 최신 세대일 때만 결과를
  /// 반영한다. 그렇지 않으면(사용자가 그 사이 다른 종목으로 전환해 더 최신
  /// 요청이 시작됨) 이 응답은 조용히 폐기한다.
  Future<void> refreshSchedule({bool force = false}) async {
    final gen = ++_scheduleGen;
    final item = catalogItem;
    loadingSchedule = true;
    scheduleError = null;
    notifyListeners();

    if (!item.isQnet || item.jmCd == null) {
      // 학교 교과 등 크롤링 미지원 종목
      if (gen != _scheduleGen) return;
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
      if (gen != _scheduleGen) return; // 더 최신 요청이 이미 진행 중 — 폐기
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
      if (gen != _scheduleGen) return;
      scheduleError = '네트워크 오류로 일정을 불러오지 못했어요.';
    } finally {
      if (gen == _scheduleGen) {
        loadingSchedule = false;
        notifyListeners();
      }
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
