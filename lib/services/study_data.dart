import 'dart:convert';
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
  Map<String, List<TopicFreq>>? _topicFreq;
  final Map<String, String> _theoryCache = {};

  Future<List<ExamPaper>> loadExams() async {
    if (_exams != null) return _exams!;
    final raw = await rootBundle.loadString('assets/data/exams.json');
    final list = jsonDecode(raw) as List;
    _exams = list
        .map((e) => ExamPaper.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        final c = b.year.compareTo(a.year);
        return c != 0 ? c : b.session.compareTo(a.session);
      });
    return _exams!;
  }

  Future<List<Mnemonic>> loadMnemonics() async {
    if (_mnemonics != null) return _mnemonics!;
    final raw = await rootBundle.loadString('assets/data/mnemonics.json');
    final list = jsonDecode(raw) as List;
    _mnemonics = list
        .map((e) => Mnemonic.fromJson(e as Map<String, dynamic>))
        .toList();
    return _mnemonics!;
  }

  Future<List<VideoLink>> loadVideos() async {
    if (_videos != null) return _videos!;
    final raw = await rootBundle.loadString('assets/data/videos.json');
    final list = jsonDecode(raw) as List;
    _videos = list
        .map((e) => VideoLink.fromJson(e as Map<String, dynamic>))
        .toList();
    return _videos!;
  }

  Future<Map<String, List<TopicFreq>>> loadTopicFreq() async {
    if (_topicFreq != null) return _topicFreq!;
    final raw = await rootBundle.loadString('assets/data/topic_freq.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _topicFreq = map.map((k, v) => MapEntry(
        k,
        (v as List)
            .map((e) => TopicFreq.fromJson(e as Map<String, dynamic>))
            .toList()));
    return _topicFreq!;
  }

  Future<String> loadTheory(String subject) async {
    if (_theoryCache.containsKey(subject)) return _theoryCache[subject]!;
    final path = kTheoryFiles[subject];
    if (path == null) return '# 자료 없음';
    final raw = await rootBundle.loadString(path);
    _theoryCache[subject] = raw;
    return raw;
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
