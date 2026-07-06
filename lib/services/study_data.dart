import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/services.dart' show rootBundle;

/// 과목 정의 (순서 고정)
const List<String> kSubjects = [
  '전자기학',
  '전력공학',
  '전기기기',
  '회로이론 및 제어공학',
  '전기설비기술기준',
];

const Map<String, String> kTheoryFiles = {
  '전자기학': 'assets/theory/01.md',
  '전력공학': 'assets/theory/02.md',
  '전기기기': 'assets/theory/03.md',
  '회로이론 및 제어공학': 'assets/theory/04.md',
  '전기설비기술기준': 'assets/theory/05.md',
};

class Question {
  final int no;
  final String subject;
  final String topic;
  final String question;
  final List<String> options;
  final int answer; // 1-based
  final bool hasImage;
  String examLabel; // 출제 회차 라벨

  Question({
    required this.no,
    required this.subject,
    required this.topic,
    required this.question,
    required this.options,
    required this.answer,
    required this.hasImage,
    this.examLabel = '',
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        no: j['no'] as int,
        subject: (j['subject'] as String?) ?? '',
        topic: (j['topic'] as String?) ?? '기타',
        question: (j['question'] as String?) ?? '',
        options: ((j['options'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        answer: (j['answer'] as int?) ?? 0,
        hasImage: (j['has_image'] as bool?) ?? false,
      );
}

class TopicFreq {
  final String topic;
  final int count;
  final int rank;
  TopicFreq({required this.topic, required this.count, required this.rank});
  factory TopicFreq.fromJson(Map<String, dynamic> j) => TopicFreq(
        topic: (j['topic'] as String?) ?? '',
        count: (j['count'] as int?) ?? 0,
        rank: (j['rank'] as int?) ?? 0,
      );
}

class ExamPaper {
  final String id;
  final String label;
  final int year;
  final String session;
  final List<Question> questions;

  ExamPaper({
    required this.id,
    required this.label,
    required this.year,
    required this.session,
    required this.questions,
  });

  factory ExamPaper.fromJson(Map<String, dynamic> j) => ExamPaper(
        id: (j['id'] as String?) ?? '',
        label: (j['label'] as String?) ?? '',
        year: (j['year'] as int?) ?? 0,
        session: (j['session'] as String?)?.toString() ?? '',
        questions: ((j['questions'] as List?) ?? const [])
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Mnemonic {
  final String subject;
  final String title;
  final String body;
  final String tip;

  Mnemonic({
    required this.subject,
    required this.title,
    required this.body,
    required this.tip,
  });

  factory Mnemonic.fromJson(Map<String, dynamic> j) => Mnemonic(
        subject: (j['subject'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        tip: (j['tip'] as String?) ?? '',
      );
}

/// 1:1 강의 노트 (토픽별 완전 강의)
class LessonSection {
  final String title;
  final String body;
  LessonSection({required this.title, required this.body});
  factory LessonSection.fromJson(Map<String, dynamic> j) => LessonSection(
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
      );
}

class LessonFormula {
  final String name;
  final String expr;
  final String note;
  LessonFormula({required this.name, required this.expr, required this.note});
  factory LessonFormula.fromJson(Map<String, dynamic> j) => LessonFormula(
        name: (j['name'] as String?) ?? '',
        expr: (j['expr'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
      );
}

class Lesson {
  final String subject;
  final String topic;
  final int freq;
  final int importance; // 1~5
  final String intro;
  final List<LessonSection> sections;
  final List<LessonFormula> formulas;
  final List<String> mnemonics;
  final String strategy;
  final List<String> traps;

  Lesson({
    required this.subject,
    required this.topic,
    required this.freq,
    required this.importance,
    required this.intro,
    required this.sections,
    required this.formulas,
    required this.mnemonics,
    required this.strategy,
    required this.traps,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        subject: (j['subject'] as String?) ?? '',
        topic: (j['topic'] as String?) ?? '',
        freq: (j['freq'] as int?) ?? 0,
        importance: (j['importance'] as int?) ?? 3,
        intro: (j['intro'] as String?) ?? '',
        sections: ((j['sections'] as List?) ?? const [])
            .map((e) => LessonSection.fromJson(e as Map<String, dynamic>))
            .toList(),
        formulas: ((j['formulas'] as List?) ?? const [])
            .map((e) => LessonFormula.fromJson(e as Map<String, dynamic>))
            .toList(),
        mnemonics: ((j['mnemonics'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        strategy: (j['strategy'] as String?) ?? '',
        traps: ((j['traps'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// 반복 출제 문제 클러스터 (문제-답 암기용)
class RepeatVariation {
  final String exam;
  final String question;
  final int answer;
  final String answerText;
  RepeatVariation({
    required this.exam,
    required this.question,
    required this.answer,
    required this.answerText,
  });
  factory RepeatVariation.fromJson(Map<String, dynamic> j) => RepeatVariation(
        exam: (j['exam'] as String?) ?? '',
        question: (j['question'] as String?) ?? '',
        answer: (j['answer'] as int?) ?? 0,
        answerText: (j['answer_text'] as String?) ?? '',
      );
}

class RepeatCluster {
  final String subject;
  final String topic;
  final int count;
  final List<String> exams;
  final String question;
  final List<String> options;
  final int answer; // 1-based
  final String answerText;
  final bool isVariation;
  final List<RepeatVariation> variations;

  RepeatCluster({
    required this.subject,
    required this.topic,
    required this.count,
    required this.exams,
    required this.question,
    required this.options,
    required this.answer,
    required this.answerText,
    required this.isVariation,
    required this.variations,
  });

  factory RepeatCluster.fromJson(Map<String, dynamic> j) => RepeatCluster(
        subject: (j['subject'] as String?) ?? '',
        topic: (j['topic'] as String?) ?? '',
        count: (j['count'] as int?) ?? 0,
        exams: ((j['exams'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        question: (j['question'] as String?) ?? '',
        options: ((j['options'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        answer: (j['answer'] as int?) ?? 0,
        answerText: (j['answer_text'] as String?) ?? '',
        isVariation: (j['is_variation'] as bool?) ?? false,
        variations: ((j['variations'] as List?) ?? const [])
            .map((e) => RepeatVariation.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class VideoLink {
  final String subject;
  final String title;
  final String channel;
  final String url;
  final String desc;

  VideoLink({
    required this.subject,
    required this.title,
    required this.channel,
    required this.url,
    required this.desc,
  });

  factory VideoLink.fromJson(Map<String, dynamic> j) => VideoLink(
        subject: (j['subject'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        channel: (j['channel'] as String?) ?? '',
        url: (j['url'] as String?) ?? '',
        desc: (j['desc'] as String?) ?? '',
      );
}

/// 학습 데이터 로더 (싱글턴 캐시)
class StudyData {
  StudyData._();
  static final StudyData instance = StudyData._();

  List<ExamPaper>? _exams;
  List<Mnemonic>? _mnemonics;
  List<VideoLink>? _videos;
  List<Lesson>? _lessons;
  List<RepeatCluster>? _repeats;
  Map<String, List<TopicFreq>>? _topicFreq;
  final Map<String, String> _theoryCache = {};

  /// 안전 JSON 리스트 로더 — 파일 하나가 깨져도 앱이 죽지 않게 방어
  Future<List<T>> _safeLoadList<T>(
      String path, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final raw = await rootBundle.loadString(path);
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('$path 로드 실패: $e');
      }
      return <T>[];
    }
  }

  Future<List<ExamPaper>> loadExams() async {
    if (_exams != null) return _exams!;
    _exams = await _safeLoadList(
        'assets/data/exams.json', ExamPaper.fromJson)
      ..sort((a, b) {
        final c = b.year.compareTo(a.year);
        return c != 0 ? c : b.session.compareTo(a.session);
      });
    return _exams!;
  }

  Future<List<Mnemonic>> loadMnemonics() async {
    if (_mnemonics != null) return _mnemonics!;
    _mnemonics = await _safeLoadList(
        'assets/data/mnemonics.json', Mnemonic.fromJson);
    return _mnemonics!;
  }

  Future<List<VideoLink>> loadVideos() async {
    if (_videos != null) return _videos!;
    _videos = await _safeLoadList(
        'assets/data/videos.json', VideoLink.fromJson);
    return _videos!;
  }

  Future<Map<String, List<TopicFreq>>> loadTopicFreq() async {
    if (_topicFreq != null) return _topicFreq!;
    try {
      final raw = await rootBundle.loadString('assets/data/topic_freq.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _topicFreq = map.map((k, v) => MapEntry(
          k,
          (v as List)
              .map((e) => TopicFreq.fromJson(e as Map<String, dynamic>))
              .toList()));
    } catch (_) {
      _topicFreq = {};
    }
    return _topicFreq!;
  }

  Future<String> loadTheory(String subject) async {
    if (_theoryCache.containsKey(subject)) return _theoryCache[subject]!;
    final path = kTheoryFiles[subject];
    if (path == null) return '# 자료 없음';
    try {
      final raw = await rootBundle.loadString(path);
      _theoryCache[subject] = raw;
      return raw;
    } catch (_) {
      return '# 자료를 불러올 수 없습니다';
    }
  }

  /// 과목별 문제 추출 (전 회차 통합, 회차 라벨 부여)
  Future<List<Question>> questionsBySubject(String subject) async {
    final exams = await loadExams();
    final out = <Question>[];
    for (final e in exams) {
      for (final q in e.questions) {
        if (q.subject == subject && q.options.length == 4 && q.answer >= 1) {
          q.examLabel = e.label;
          out.add(q);
        }
      }
    }
    return out;
  }

  /// 빈출도 순 정렬: 출제 빈도가 높은 토픽의 문제부터 (최신 회차 우선)
  Future<List<Question>> questionsByFrequency(String subject) async {
    final qs = await questionsBySubject(subject);
    final freq = await loadTopicFreq();
    final rankMap = <String, int>{
      for (final t in freq[subject] ?? <TopicFreq>[]) t.topic: t.rank
    };
    qs.sort((a, b) {
      final ra = rankMap[a.topic] ?? 999;
      final rb = rankMap[b.topic] ?? 999;
      return ra.compareTo(rb);
    });
    return qs;
  }

  /// 1:1 강의 노트 로드
  Future<List<Lesson>> loadLessons() async {
    if (_lessons != null) return _lessons!;
    _lessons = await _safeLoadList(
        'assets/data/lessons.json', Lesson.fromJson);
    return _lessons!;
  }

  /// 과목+토픽에 정확히 매칭되는 강의 (전수조사로 100% 커버 보장)
  Future<Lesson?> lessonFor(String subject, String topic) async {
    final all = await loadLessons();
    for (final l in all) {
      if (l.subject == subject && l.topic == topic) return l;
    }
    // 폴백: 같은 과목의 '기타' 강의
    for (final l in all) {
      if (l.subject == subject && l.topic == '기타') return l;
    }
    return null;
  }

  /// 과목별 강의 목록 (빈출순)
  Future<List<Lesson>> lessonsBySubject(String subject) async {
    final all = await loadLessons();
    final out = all.where((l) => l.subject == subject).toList()
      ..sort((a, b) => b.freq.compareTo(a.freq));
    return out;
  }

  /// 반복 출제 클러스터 로드 (빈도순 정렬 완료 상태)
  Future<List<RepeatCluster>> loadRepeats() async {
    if (_repeats != null) return _repeats!;
    _repeats = await _safeLoadList(
        'assets/data/repeat_questions.json', RepeatCluster.fromJson);
    return _repeats!;
  }

  /// 과목별 반복 문제 (빈도순)
  Future<List<RepeatCluster>> repeatsBySubject(String? subject) async {
    final all = await loadRepeats();
    if (subject == null) return all;
    return all.where((r) => r.subject == subject).toList();
  }

  /// 과목+토픽 관련 암기법 찾기
  Future<List<Mnemonic>> mnemonicsFor(String subject, String topic) async {
    final all = await loadMnemonics();
    final subjectMatch =
        all.where((m) => m.subject == subject || m.subject == '공통').toList();
    // 토픽 키워드가 제목/본문에 포함되면 우선순위
    final kw = topic.split(RegExp(r'[·\s]')).where((s) => s.length >= 2);
    subjectMatch.sort((a, b) {
      int score(Mnemonic m) {
        var s = 0;
        for (final k in kw) {
          if (m.title.contains(k) || m.body.contains(k)) s += 2;
        }
        return -s;
      }
      return score(a).compareTo(score(b));
    });
    return subjectMatch;
  }
}
