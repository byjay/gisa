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
  final String explanation; // 문제별 해설
  final int difficulty; // 1=하, 2=중, 3=상
  final double freqScore; // 0~100 출제빈도 점수
  String examLabel; // 출제 회차 라벨

  Question({
    required this.no,
    required this.subject,
    required this.topic,
    required this.question,
    required this.options,
    required this.answer,
    required this.hasImage,
    this.explanation = '',
    this.difficulty = 2,
    this.freqScore = 0,
    this.examLabel = '',
  });

  String get difficultyLabel =>
      difficulty == 1 ? '하' : (difficulty == 3 ? '상' : '중');

  /// 문제 고유 ID (오답노트·북마크 추적용)
  String get qid => '$examLabel|$subject|$no';

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
        explanation: (j['explanation'] as String?) ?? '',
        difficulty: (j['difficulty'] as int?) ?? 2,
        freqScore: ((j['freq_score'] as num?) ?? 0).toDouble(),
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

/// 풀이 레시피 — 토픽별 문제 풀이 순서 + 공식 적용법 (만능 선생님)
class RecipeFormula {
  final String expr; // 공식
  final String how; // 적용 방법
  RecipeFormula({required this.expr, required this.how});
  factory RecipeFormula.fromJson(Map<String, dynamic> j) => RecipeFormula(
        expr: (j['expr'] as String?) ?? '',
        how: (j['how'] as String?) ?? '',
      );
}

class SolutionRecipe {
  final String topic;
  final String check; // 문제 유형 판별 체크포인트
  final List<String> steps; // 풀이 순서 1→N
  final List<RecipeFormula> formulas; // 공식 + 적용법
  SolutionRecipe({
    required this.topic,
    required this.check,
    required this.steps,
    required this.formulas,
  });
  factory SolutionRecipe.fromJson(Map<String, dynamic> j) => SolutionRecipe(
        topic: (j['topic'] as String?) ?? '',
        check: (j['check'] as String?) ?? '',
        steps: ((j['steps'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        formulas: ((j['formulas'] as List?) ?? const [])
            .map((e) => RecipeFormula.fromJson(e as Map<String, dynamic>))
            .toList(),
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

/// 30일 학습 플랜
class PlanDay {
  final int day;
  final int week;
  final String phase;
  final String subject;
  final String title;
  final List<String> topics;
  final int goalQuestions;
  final List<String> tasks;

  PlanDay({
    required this.day,
    required this.week,
    required this.phase,
    required this.subject,
    required this.title,
    required this.topics,
    required this.goalQuestions,
    required this.tasks,
  });

  factory PlanDay.fromJson(Map<String, dynamic> j) => PlanDay(
        day: (j['day'] as int?) ?? 0,
        week: (j['week'] as int?) ?? 0,
        phase: (j['phase'] as String?) ?? '',
        subject: (j['subject'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        topics:
            ((j['topics'] as List?) ?? const []).map((e) => e.toString()).toList(),
        goalQuestions: (j['goal_questions'] as int?) ?? 0,
        tasks:
            ((j['tasks'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

class StudyPlan {
  final String title;
  final String description;
  final List<String> strategy;
  final List<PlanDay> days;

  StudyPlan({
    required this.title,
    required this.description,
    required this.strategy,
    required this.days,
  });

  factory StudyPlan.fromJson(Map<String, dynamic> j) => StudyPlan(
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        strategy: ((j['strategy'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        days: ((j['days'] as List?) ?? const [])
            .map((e) => PlanDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 슬라이드 카드 (30일 이론 덱)
class SlideCard {
  final String type; // mission/concept/core/formula/mnemonic/trap/strategy/recap
  final String topic;
  final String title;
  final String body;

  SlideCard({
    required this.type,
    required this.topic,
    required this.title,
    required this.body,
  });

  factory SlideCard.fromJson(Map<String, dynamic> j) => SlideCard(
        type: (j['type'] as String?) ?? 'core',
        topic: (j['topic'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
      );
}

class SlideDeck {
  final int day;
  final String subject;
  final String title;
  final String phase;
  final List<SlideCard> cards;

  SlideDeck({
    required this.day,
    required this.subject,
    required this.title,
    required this.phase,
    required this.cards,
  });

  factory SlideDeck.fromJson(Map<String, dynamic> j) => SlideDeck(
        day: (j['day'] as int?) ?? 0,
        subject: (j['subject'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        phase: (j['phase'] as String?) ?? '',
        cards: ((j['cards'] as List?) ?? const [])
            .map((e) => SlideCard.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 실기 대비 카드
class SilgiItem {
  final String category;
  final String title;
  final String linkSubject; // 필기 과목 연동
  final int importance;
  final String question;
  final String answer;
  final String memo;

  SilgiItem({
    required this.category,
    required this.title,
    required this.linkSubject,
    required this.importance,
    required this.question,
    required this.answer,
    required this.memo,
  });

  factory SilgiItem.fromJson(Map<String, dynamic> j) => SilgiItem(
        category: (j['category'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        linkSubject: (j['link_subject'] as String?) ?? '',
        importance: (j['importance'] as int?) ?? 3,
        question: (j['question'] as String?) ?? '',
        answer: (j['answer'] as String?) ?? '',
        memo: (j['memo'] as String?) ?? '',
      );
}

class SilgiData {
  final String title;
  final String overview;
  final List<String> strategy;
  final List<SilgiItem> items;

  SilgiData({
    required this.title,
    required this.overview,
    required this.strategy,
    required this.items,
  });

  factory SilgiData.fromJson(Map<String, dynamic> j) => SilgiData(
        title: (j['title'] as String?) ?? '',
        overview: (j['overview'] as String?) ?? '',
        strategy: ((j['strategy'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        items: ((j['items'] as List?) ?? const [])
            .map((e) => SilgiItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 공식 마스터 가이드 — 읽는법·기호뜻·이해법·암기법·예제
class FormulaSymbol {
  final String sym;
  final String meaning;
  FormulaSymbol({required this.sym, required this.meaning});
  factory FormulaSymbol.fromJson(Map<String, dynamic> j) => FormulaSymbol(
        sym: (j['sym'] as String?) ?? '',
        meaning: (j['meaning'] as String?) ?? '',
      );
}

class FormulaGuide {
  final String subject;
  final String topic;
  final int importance;
  final String name;
  final String expr;
  final String read; // 소리내어 읽는 법
  final List<FormulaSymbol> symbols;
  final String understand; // 비유 이해법
  final String mnemonic; // 암기법
  final String example; // 기출 예제

  FormulaGuide({
    required this.subject,
    required this.topic,
    required this.importance,
    required this.name,
    required this.expr,
    required this.read,
    required this.symbols,
    required this.understand,
    required this.mnemonic,
    required this.example,
  });

  factory FormulaGuide.fromJson(Map<String, dynamic> j) => FormulaGuide(
        subject: (j['subject'] as String?) ?? '',
        topic: (j['topic'] as String?) ?? '',
        importance: (j['importance'] as int?) ?? 3,
        name: (j['name'] as String?) ?? '',
        expr: (j['expr'] as String?) ?? '',
        read: (j['read'] as String?) ?? '',
        symbols: ((j['symbols'] as List?) ?? const [])
            .map((e) => FormulaSymbol.fromJson(e as Map<String, dynamic>))
            .toList(),
        understand: (j['understand'] as String?) ?? '',
        mnemonic: (j['mnemonic'] as String?) ?? '',
        example: (j['example'] as String?) ?? '',
      );
}

/// 초보자 기초 사전 (단위·기호·핵심 개념)
class BasicTerm {
  final String category;
  final String term;
  final String easy; // 쉬운 한 줄 설명
  final String detail; // 상세 설명

  BasicTerm({
    required this.category,
    required this.term,
    required this.easy,
    required this.detail,
  });

  factory BasicTerm.fromJson(Map<String, dynamic> j) => BasicTerm(
        category: (j['category'] as String?) ?? '',
        term: (j['term'] as String?) ?? '',
        easy: (j['easy'] as String?) ?? '',
        detail: (j['detail'] as String?) ?? '',
      );
}

class FormulaGuideData {
  final String title;
  final String intro;
  final List<FormulaGuide> formulas;
  final List<BasicTerm> basics;

  FormulaGuideData({
    required this.title,
    required this.intro,
    required this.formulas,
    required this.basics,
  });

  factory FormulaGuideData.fromJson(Map<String, dynamic> j) => FormulaGuideData(
        title: (j['title'] as String?) ?? '',
        intro: (j['intro'] as String?) ?? '',
        formulas: ((j['formulas'] as List?) ?? const [])
            .map((e) => FormulaGuide.fromJson(e as Map<String, dynamic>))
            .toList(),
        basics: ((j['basics'] as List?) ?? const [])
            .map((e) => BasicTerm.fromJson(e as Map<String, dynamic>))
            .toList(),
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
  StudyPlan? _plan;
  List<SlideDeck>? _slideDecks;
  SilgiData? _silgi;
  final Map<String, String> _theoryCache = {};

  /// 30일 학습 플랜 로드
  Future<StudyPlan?> loadPlan() async {
    if (_plan != null) return _plan;
    try {
      final raw = await rootBundle.loadString('assets/data/study_plan.json');
      _plan = StudyPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('study_plan.json 로드 실패: $e');
    }
    return _plan;
  }

  /// 30일 슬라이드 덱 로드
  Future<List<SlideDeck>> loadSlideDecks() async {
    if (_slideDecks != null) return _slideDecks!;
    _slideDecks = await _safeLoadList(
        'assets/data/theory_slides.json', SlideDeck.fromJson);
    return _slideDecks!;
  }

  FormulaGuideData? _formulaGuide;
  Map<String, dynamic>? _examInfo;

  /// 2026 시험정보 (일정·출제기준·전략) 로드 — raw JSON map
  Future<Map<String, dynamic>?> loadExamInfo() async {
    if (_examInfo != null) return _examInfo;
    try {
      final raw =
          await rootBundle.loadString('assets/data/exam_info_2026.json');
      _examInfo = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('exam_info_2026.json 로드 실패: $e');
    }
    return _examInfo;
  }

  /// 공식 마스터 가이드 로드
  Future<FormulaGuideData?> loadFormulaGuide() async {
    if (_formulaGuide != null) return _formulaGuide;
    try {
      final raw =
          await rootBundle.loadString('assets/data/formula_guide.json');
      _formulaGuide =
          FormulaGuideData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('formula_guide.json 로드 실패: $e');
    }
    return _formulaGuide;
  }

  /// 실기 데이터 로드
  Future<SilgiData?> loadSilgi() async {
    if (_silgi != null) return _silgi;
    try {
      final raw = await rootBundle.loadString('assets/data/silgi.json');
      _silgi = SilgiData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('silgi.json 로드 실패: $e');
    }
    return _silgi;
  }

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

  List<SolutionRecipe>? _recipes;
  Map<String, SolutionRecipe>? _recipeByTopic;

  /// 풀이 레시피 로드 (42개 토픽 — 풀이 순서 + 공식 적용법)
  Future<List<SolutionRecipe>> loadRecipes() async {
    if (_recipes != null) return _recipes!;
    _recipes = await _safeLoadList(
        'assets/data/solution_recipes.json', SolutionRecipe.fromJson);
    _recipeByTopic = {for (final r in _recipes!) r.topic: r};
    return _recipes!;
  }

  /// 토픽으로 레시피 즉시 조회 (loadRecipes 후 사용)
  SolutionRecipe? recipeForTopic(String topic) => _recipeByTopic?[topic];

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

  /// 토픽별 문제 추출 (슬라이드→기출 즉시 연결용)
  Future<List<Question>> questionsByTopic(String topic) async {
    final exams = await loadExams();
    final out = <Question>[];
    for (final e in exams) {
      for (final q in e.questions) {
        if (q.topic == topic && q.options.length == 4 && q.answer >= 1) {
          q.examLabel = e.label;
          out.add(q);
        }
      }
    }
    // 빈출 우선 정렬
    out.sort((a, b) => b.freqScore.compareTo(a.freqScore));
    return out;
  }

  /// 빈출도 순 정렬: 문항별 freq_score 높은 순 (반복출제 + 토픽빈도)
  Future<List<Question>> questionsByFrequency(String subject) async {
    final qs = await questionsBySubject(subject);
    qs.sort((a, b) => b.freqScore.compareTo(a.freqScore));
    return qs;
  }

  /// 난이도 순 정렬: 쉬운 문제부터 (단계별 학습용)
  Future<List<Question>> questionsByDifficulty(String subject,
      {bool easyFirst = true}) async {
    final qs = await questionsBySubject(subject);
    qs.sort((a, b) {
      final c = easyFirst
          ? a.difficulty.compareTo(b.difficulty)
          : b.difficulty.compareTo(a.difficulty);
      return c != 0 ? c : b.freqScore.compareTo(a.freqScore);
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
