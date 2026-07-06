import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

class AppProvider extends ChangeNotifier {
  late Box _examBox;
  late Box _sessionBox;
  late Box _noteBox;
  late Box _settingsBox;

  List<Exam> exams = [];
  List<StudySession> sessions = [];
  List<WrongNote> notes = [];

  // Goal settings
  int dailyGoalMinutes = 120;
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
    dailyGoalMinutes = (_settingsBox.get('dailyGoal') as int?) ?? 120;
    weeklyGoalMinutes = (_settingsBox.get('weeklyGoal') as int?) ?? 600;
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

  /// Streak: consecutive days with study up to today (or yesterday)
  int get streak {
    int count = 0;
    var day = DateTime.now();
    if (minutesOnDate(day) == 0) {
      day = day.subtract(const Duration(days: 1));
    }
    while (minutesOnDate(day) > 0) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
