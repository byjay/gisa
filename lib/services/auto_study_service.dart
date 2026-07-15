import 'package:shared_preferences/shared_preferences.dart';

import 'progress_service.dart';
import 'study_data.dart';

enum AutoStudyTaskKind { dueReview, wrongRecovery, adaptivePractice, miniMock }

class AutoStudyTask {
  final String id;
  final AutoStudyTaskKind kind;
  final String title;
  final String reason;
  final String subject;
  final int estimatedMinutes;
  final List<Question> questions;

  const AutoStudyTask({
    required this.id,
    required this.kind,
    required this.title,
    required this.reason,
    required this.subject,
    required this.estimatedMinutes,
    required this.questions,
  });
}

class AutoStudyPlan {
  final String trackName;
  final int targetMinutes;
  final int studiedMinutes;
  final List<AutoStudyTask> tasks;
  final Set<String> completedTaskIds;

  const AutoStudyPlan({
    required this.trackName,
    required this.targetMinutes,
    required this.studiedMinutes,
    required this.tasks,
    required this.completedTaskIds,
  });

  int get completedCount =>
      tasks.where((task) => completedTaskIds.contains(task.id)).length;

  int get totalQuestions =>
      tasks.fold(0, (sum, task) => sum + task.questions.length);

  int get plannedMinutes =>
      tasks.fold(0, (sum, task) => sum + task.estimatedMinutes);

  double get progress => tasks.isEmpty ? 1 : completedCount / tasks.length;

  AutoStudyTask? get nextTask {
    for (final task in tasks) {
      if (!completedTaskIds.contains(task.id)) return task;
    }
    return null;
  }
}

/// 선택된 학습 트랙의 문항과 사용자 기록을 결합해 매일 자동 큐를 만든다.
/// 새 자격증/과목도 ExamTrack과 JSON 데이터만 연결하면 같은 엔진을 사용한다.
class AutoStudyService {
  AutoStudyService._();
  static final AutoStudyService instance = AutoStudyService._();

  static int questionBudget({
    required int dailyGoalMinutes,
    required int studiedMinutes,
  }) {
    final remaining = (dailyGoalMinutes - studiedMinutes).clamp(10, 120);
    return (remaining / 2).ceil().clamp(10, 40);
  }

  static List<AutoStudyTaskKind> priorityOrder({
    required int dueCount,
    required int wrongCount,
    required bool includeMock,
  }) {
    return [
      if (dueCount > 0) AutoStudyTaskKind.dueReview,
      if (wrongCount > 0) AutoStudyTaskKind.wrongRecovery,
      AutoStudyTaskKind.adaptivePractice,
      if (includeMock) AutoStudyTaskKind.miniMock,
    ];
  }

  Future<AutoStudyPlan> buildPlan({
    required int dailyGoalMinutes,
    required int studiedMinutes,
  }) async {
    final progress = ProgressService.instance;
    final track = StudyData.instance.track;
    final budget = questionBudget(
      dailyGoalMinutes: dailyGoalMinutes,
      studiedMinutes: studiedMinutes,
    );
    final completed = await _completedIds();
    final used = <String>{};
    final tasks = <AutoStudyTask>[];

    final dueIds = await progress.dueReviewQids();
    final due = await progress.resolveQuestions(dueIds);
    final dueQuestions = _unique(due, used, limit: 10);
    if (dueQuestions.isNotEmpty) {
      tasks.add(
        AutoStudyTask(
          id: 'due-review',
          kind: AutoStudyTaskKind.dueReview,
          title: '기억 회복 복습',
          reason: '망각 직전 문항을 먼저 꺼내 장기기억으로 전환해요.',
          subject: _dominantSubject(dueQuestions),
          estimatedMinutes: _minutes(dueQuestions.length),
          questions: dueQuestions,
        ),
      );
    }

    final wrongIds = await progress.wrongQids();
    final wrong = await progress.resolveQuestions(wrongIds);
    final wrongQuestions = _unique(wrong, used, limit: 10);
    if (wrongQuestions.isNotEmpty) {
      tasks.add(
        AutoStudyTask(
          id: 'wrong-recovery',
          kind: AutoStudyTaskKind.wrongRecovery,
          title: '오답 회복 훈련',
          reason: '최근 틀린 개념을 바로 다시 풀어 같은 실수를 차단해요.',
          subject: _dominantSubject(wrongQuestions),
          estimatedMinutes: _minutes(wrongQuestions.length),
          questions: wrongQuestions,
        ),
      );
    }

    final alreadyPlanned = tasks.fold<int>(
      0,
      (sum, task) => sum + task.questions.length,
    );
    final adaptiveTarget = (budget - alreadyPlanned).clamp(8, 20);
    final smart = await progress.buildSmartSet(count: adaptiveTarget + 12);
    var adaptive = _unique(smart, used, limit: adaptiveTarget);
    if (adaptive.isEmpty) {
      adaptive = await _fallbackQuestions(used, adaptiveTarget);
    }
    if (adaptive.isNotEmpty) {
      final weak = await progress.weakTopics(limit: 1);
      final weakLabel = weak.isEmpty ? '출제 빈도' : '${weak.first.$2} 약점';
      tasks.add(
        AutoStudyTask(
          id: 'adaptive-practice',
          kind: AutoStudyTaskKind.adaptivePractice,
          title: '맞춤 실력 성장',
          reason: '$weakLabel과 기출 빈도를 계산해 가장 효율적인 문항을 골랐어요.',
          subject: _dominantSubject(adaptive),
          estimatedMinutes: _minutes(adaptive.length),
          questions: adaptive,
        ),
      );
    }

    if (dailyGoalMinutes >= 60) {
      final mock = await _miniMock(used, 10);
      if (mock.isNotEmpty) {
        tasks.add(
          AutoStudyTask(
            id: 'mini-mock',
            kind: AutoStudyTaskKind.miniMock,
            title: '10문항 미니 실전',
            reason: '마지막에는 과목을 섞어 인출 속도와 실전 감각을 점검해요.',
            subject: '전 과목',
            estimatedMinutes: 15,
            questions: mock,
          ),
        );
      }
    }

    return AutoStudyPlan(
      trackName: track.name,
      targetMinutes: dailyGoalMinutes,
      studiedMinutes: studiedMinutes,
      tasks: tasks,
      completedTaskIds: completed,
    );
  }

  Future<void> markCompleted(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _completionKey();
    final ids = (prefs.getStringList(key) ?? <String>[]).toSet()..add(taskId);
    await prefs.setStringList(key, ids.toList()..sort());
  }

  Future<void> resetToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completionKey());
  }

  Future<Set<String>> _completedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_completionKey()) ?? <String>[]).toSet();
  }

  String _completionKey() {
    final now = DateTime.now();
    final day =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return 'auto_study_${StudyData.instance.track.id}_$day';
  }

  List<Question> _unique(
    Iterable<Question> source,
    Set<String> used, {
    required int limit,
  }) {
    final out = <Question>[];
    for (final question in source) {
      if (question.options.length != 4 || question.answer < 1) continue;
      if (used.add(question.qid)) out.add(question);
      if (out.length >= limit) break;
    }
    return out;
  }

  Future<List<Question>> _fallbackQuestions(Set<String> used, int limit) async {
    final exams = await StudyData.instance.loadExams();
    final pool = <Question>[];
    for (final exam in exams) {
      for (final question in exam.questions) {
        question.examLabel = exam.label;
        pool.add(question);
      }
    }
    pool.sort((a, b) => b.freqScore.compareTo(a.freqScore));
    return _unique(pool, used, limit: limit);
  }

  Future<List<Question>> _miniMock(Set<String> used, int limit) async {
    final exams = await StudyData.instance.loadExams();
    if (exams.isEmpty) return [];
    final pool = <Question>[];
    for (final question in exams.first.questions) {
      question.examLabel = exams.first.label;
      pool.add(question);
    }
    pool.shuffle();
    return _unique(pool, used, limit: limit);
  }

  int _minutes(int questions) => (questions * 1.5).ceil();

  String _dominantSubject(List<Question> questions) {
    final counts = <String, int>{};
    for (final question in questions) {
      counts[question.subject] = (counts[question.subject] ?? 0) + 1;
    }
    if (counts.isEmpty) return '전 과목';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
