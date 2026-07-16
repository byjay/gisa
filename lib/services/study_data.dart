import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'exam_track.dart';

/// 현재 선택된 종목 (기본: 전기기사). StudyData.setTrack 으로 변경된다.
ExamTrack _currentTrack = kExamTracks.first;

/// JSON 값을 문자열 리스트로 안전 변환 (top-level 헬퍼).
List<String> _strList(dynamic v) => switch (v) {
      final List l => l.map((e) => e.toString()).toList(),
      final String s when s.isNotEmpty => [s],
      _ => const <String>[],
    };

/// 현재 종목의 과목 목록 (순서 고정) — 전 화면에서 이 상수처럼 사용.
List<String> get kSubjects => _currentTrack.subjects;

/// 현재 종목의 이론 파일 경로 맵.
Map<String, String> get kTheoryFiles => _currentTrack.theoryFiles;

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

  /// 문제 고유 ID (오답노트·북마크·진척 추적용)
  ///
  /// ⚠️ 종목(track) 접두어를 포함한다. 향후 자격증 10종으로 확장하거나
  /// 단일 과목 앱으로 분리 판매할 때, 서로 다른 종목의 동일 회차·과목·번호
  /// 문제가 진척 데이터에서 충돌하지 않도록 한다.
  String get qid => '${_currentTrack.id}|$examLabel|$subject|$no';

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

  // ── 레벨별 학습 확장 필드 (R36) ──
  /// 왕초보 기초 설명 — 공식·개념의 '왜'를 비유로 풀어주는 도입부
  final String basicExplain;

  /// 시험에 이렇게 나온다 — 실제 출제 패턴 (문항 유형·단서 키워드)
  final List<String> examHow;

  /// 필수 암기 — 시험장 직행 최우선 암기 항목 (골드 하이라이트 렌더)
  final List<String> must;

  /// 심화 암기 — 만점·고득점용 고급 포인트 (접이식 렌더)
  final List<String> advanced;

  /// 실기 연계 포인트 — 필기 이론이 실기에서 어떻게 확장되는지
  final String silgi;

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
    this.basicExplain = '',
    this.examHow = const [],
    this.must = const [],
    this.advanced = const [],
    this.silgi = '',
  });

  static List<String> _strList(dynamic v) => switch (v) {
        final List l => l.map((e) => e.toString()).toList(),
        final String s when s.isNotEmpty => [s],
        _ => const <String>[],
      };

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
        basicExplain: (j['basic_explain'] as String?) ?? '',
        examHow: _strList(j['exam_how']),
        must: _strList(j['must']),
        advanced: _strList(j['advanced']),
        silgi: (j['silgi'] as String?) ?? '',
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
        // strategy 는 트랙별 JSON 에 따라 List<String> 또는 String 이 올 수 있어
        // 두 형식 모두 허용한다 (String 이면 단일 항목 리스트로 변환).
        strategy: switch (j['strategy']) {
          final List l => l.map((e) => e.toString()).toList(),
          final String s when s.isNotEmpty => [s],
          _ => const <String>[],
        },
        days: ((j['days'] as List?) ?? const [])
            .map((e) => PlanDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 합격 공부법 가이드 — 딥리서치(합격후기·기출현황) 기반 학습 전략
class StudyGuide {
  final String title;
  final String intro;
  final GuideNote? examNote; // 기출 데이터 신뢰도 안내
  final GuideOrder? order; // 과목 공부 순서 (전공/비전공)
  final List<GuideSubject> subjects;
  final GuideList? principles; // 합격자 공통 원칙
  final GuidePeriod? period; // 권장 학습 기간

  StudyGuide({
    required this.title,
    required this.intro,
    required this.examNote,
    required this.order,
    required this.subjects,
    required this.principles,
    required this.period,
  });

  factory StudyGuide.fromJson(Map<String, dynamic> j) => StudyGuide(
        title: (j['title'] as String?) ?? '합격 공부법',
        intro: (j['intro'] as String?) ?? '',
        examNote: j['exam_data_note'] is Map
            ? GuideNote.fromJson(j['exam_data_note'] as Map<String, dynamic>)
            : null,
        order: j['order'] is Map
            ? GuideOrder.fromJson(j['order'] as Map<String, dynamic>)
            : null,
        subjects: ((j['subjects'] as List?) ?? const [])
            .map((e) => GuideSubject.fromJson(e as Map<String, dynamic>))
            .toList(),
        principles: j['principles'] is Map
            ? GuideList.fromJson(j['principles'] as Map<String, dynamic>)
            : null,
        period: j['period'] is Map
            ? GuidePeriod.fromJson(j['period'] as Map<String, dynamic>)
            : null,
      );
}

class GuideNote {
  final String title;
  final String body;
  final List<String> highlights;
  GuideNote(
      {required this.title, required this.body, required this.highlights});
  factory GuideNote.fromJson(Map<String, dynamic> j) => GuideNote(
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        highlights: _strList(j['highlights']),
      );
}

class GuideOrder {
  final String title;
  final String body;
  final OrderPath? nonMajor;
  final OrderPath? major;
  GuideOrder(
      {required this.title,
      required this.body,
      required this.nonMajor,
      required this.major});
  factory GuideOrder.fromJson(Map<String, dynamic> j) => GuideOrder(
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        nonMajor: j['non_major'] is Map
            ? OrderPath.fromJson(j['non_major'] as Map<String, dynamic>)
            : null,
        major: j['major'] is Map
            ? OrderPath.fromJson(j['major'] as Map<String, dynamic>)
            : null,
      );
}

class OrderPath {
  final String label;
  final String reason;
  final List<String> steps;
  OrderPath({required this.label, required this.reason, required this.steps});
  factory OrderPath.fromJson(Map<String, dynamic> j) => OrderPath(
        label: (j['label'] as String?) ?? '',
        reason: (j['reason'] as String?) ?? '',
        steps: _strList(j['steps']),
      );
}

class GuideSubject {
  final String name;
  final String role;
  final String method;
  final List<String> tips;
  GuideSubject(
      {required this.name,
      required this.role,
      required this.method,
      required this.tips});
  factory GuideSubject.fromJson(Map<String, dynamic> j) => GuideSubject(
        name: (j['name'] as String?) ?? '',
        role: (j['role'] as String?) ?? '',
        method: (j['method'] as String?) ?? '',
        tips: _strList(j['tips']),
      );
}

class GuideList {
  final String title;
  final List<String> items;
  GuideList({required this.title, required this.items});
  factory GuideList.fromJson(Map<String, dynamic> j) => GuideList(
        title: (j['title'] as String?) ?? '',
        items: _strList(j['items']),
      );
}

class GuidePeriod {
  final String title;
  final String body;
  final List<List<String>> table; // [라벨, 시간, 기간]
  GuidePeriod({required this.title, required this.body, required this.table});
  factory GuidePeriod.fromJson(Map<String, dynamic> j) => GuidePeriod(
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        table: ((j['table'] as List?) ?? const [])
            .map<List<String>>((row) => _strList(row))
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
        // 관대한 파싱: 구 스키마(topic/subject/body)도 수용
        category: (j['category'] as String?) ?? (j['topic'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        linkSubject:
            (j['link_subject'] as String?) ?? (j['subject'] as String?) ?? '',
        importance: (j['importance'] as num?)?.toInt() ?? 3,
        question: (j['question'] as String?) ?? '',
        answer: (j['answer'] as String?) ?? (j['body'] as String?) ?? '',
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
        // 관대한 파싱: strategy가 문자열이어도, 리스트여도 모두 수용
        strategy: switch (j['strategy']) {
          final List l => l.map((e) => e.toString()).toList(),
          final String s when s.isNotEmpty => [s],
          _ => const <String>[],
        },
        items: ((j['items'] as List?) ?? const [])
            .map((e) => SilgiItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ─── 회로도 마스터 (모터 제어반) — 전 종목 공통 ───
class CircuitLegend {
  final String code;
  final String name;
  final String desc;
  final String svg;
  CircuitLegend(
      {required this.code,
      required this.name,
      required this.desc,
      required this.svg});
  factory CircuitLegend.fromJson(Map<String, dynamic> j) => CircuitLegend(
        code: (j['code'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        desc: (j['desc'] as String?) ?? '',
        svg: (j['svg'] as String?) ?? '',
      );
}

class CircuitStep {
  final String title;
  final String body;
  final String tip;
  final String svg;
  CircuitStep(
      {required this.title,
      required this.body,
      required this.tip,
      required this.svg});
  factory CircuitStep.fromJson(Map<String, dynamic> j) => CircuitStep(
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        tip: (j['tip'] as String?) ?? '',
        svg: (j['svg'] as String?) ?? '',
      );
}

class CircuitRule {
  final String title;
  final String body;
  CircuitRule({required this.title, required this.body});
  factory CircuitRule.fromJson(Map<String, dynamic> j) => CircuitRule(
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
      );
}

class CircuitChecklist {
  final String item;
  final String done;
  CircuitChecklist({required this.item, required this.done});
  factory CircuitChecklist.fromJson(Map<String, dynamic> j) => CircuitChecklist(
        item: (j['item'] as String?) ?? '',
        done: (j['done'] as String?) ?? '',
      );
}

/// 마스터 태그표 한 행 — 분기 헤더(branch) 또는 부품 행(stage/tag/wire/ref/desc)
class CircuitMasterRow {
  final String branch; // 비어있지 않으면 그룹 헤더
  final String stage;
  final String tag;
  final String wire;
  final String ref;
  final String desc;
  bool get isHeader => branch.isNotEmpty;
  CircuitMasterRow({
    required this.branch,
    required this.stage,
    required this.tag,
    required this.wire,
    required this.ref,
    required this.desc,
  });
  factory CircuitMasterRow.fromJson(Map<String, dynamic> j) => CircuitMasterRow(
        branch: (j['branch'] as String?) ?? '',
        stage: (j['stage'] as String?) ?? '',
        tag: (j['tag'] as String?) ?? '',
        wire: (j['wire'] as String?) ?? '',
        ref: (j['ref'] as String?) ?? '',
        desc: (j['desc'] as String?) ?? '',
      );
}

class CircuitGuide {
  final String title;
  final String overview;
  final List<CircuitLegend> legend;
  final List<CircuitStep> steps;
  final List<CircuitRule> rules;
  final List<CircuitChecklist> checklist;
  final List<CircuitMasterRow> master;
  CircuitGuide({
    required this.title,
    required this.overview,
    required this.legend,
    required this.steps,
    required this.rules,
    required this.checklist,
    required this.master,
  });
  factory CircuitGuide.fromJson(Map<String, dynamic> j) => CircuitGuide(
        title: (j['title'] as String?) ?? '',
        overview: (j['overview'] as String?) ?? '',
        legend: ((j['legend'] as List?) ?? const [])
            .map((e) => CircuitLegend.fromJson(e as Map<String, dynamic>))
            .toList(),
        steps: ((j['steps'] as List?) ?? const [])
            .map((e) => CircuitStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        rules: ((j['rules'] as List?) ?? const [])
            .map((e) => CircuitRule.fromJson(e as Map<String, dynamic>))
            .toList(),
        checklist: ((j['checklist'] as List?) ?? const [])
            .map((e) => CircuitChecklist.fromJson(e as Map<String, dynamic>))
            .toList(),
        master: ((j['master'] as List?) ?? const [])
            .map((e) => CircuitMasterRow.fromJson(e as Map<String, dynamic>))
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
        // 관대한 파싱: 구 스키마의 desc를 이해법으로 대체
        understand:
            (j['understand'] as String?) ?? (j['desc'] as String?) ?? '',
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

  /// 현재 종목 폴더 (assets/data/[dir]/)
  String get _dir => _currentTrack.dir;

  /// data 파일 경로 헬퍼 — 종목 폴더를 앞에 붙인다.
  String _p(String file) => 'assets/data/$_dir/$file';

  /// 종목 전환: 캐시를 모두 비우고 다음 로드부터 새 종목 데이터를 읽는다.
  void setTrack(ExamTrack track) {
    if (_currentTrack.id == track.id) return;
    _currentTrack = track;
    _clearCache();
  }

  ExamTrack get track => _currentTrack;

  void _clearCache() {
    _exams = null;
    _mnemonics = null;
    _videos = null;
    _lessons = null;
    _repeats = null;
    _topicFreq = null;
    _plan = null;
    _guide = null;
    _slideDecks = null;
    _silgi = null;
    _formulaGuide = null;
    _examInfo = null;
    _recipes = null;
    _recipeByTopic = null;
    _theoryCache.clear();
  }

  List<ExamPaper>? _exams;
  List<Mnemonic>? _mnemonics;
  List<VideoLink>? _videos;
  List<Lesson>? _lessons;
  List<RepeatCluster>? _repeats;
  Map<String, List<TopicFreq>>? _topicFreq;
  StudyPlan? _plan;
  StudyGuide? _guide;
  List<SlideDeck>? _slideDecks;
  SilgiData? _silgi;
  final Map<String, String> _theoryCache = {};

  /// 30일 학습 플랜 로드
  Future<StudyPlan?> loadPlan() async {
    if (_plan != null) return _plan;
    try {
      final raw = await rootBundle.loadString(_p('study_plan.json'));
      _plan = StudyPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('study_plan.json 로드 실패: $e');
    }
    return _plan;
  }

  /// 합격 공부법 가이드 로드 (딥리서치 기반)
  Future<StudyGuide?> loadStudyGuide() async {
    if (_guide != null) return _guide;
    try {
      final raw = await rootBundle.loadString(_p('study_guide.json'));
      _guide = StudyGuide.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('study_guide.json 로드 실패: $e');
    }
    return _guide;
  }

  /// 30일 슬라이드 덱 로드
  Future<List<SlideDeck>> loadSlideDecks() async {
    if (_slideDecks != null) return _slideDecks!;
    _slideDecks = await _safeLoadList(
        _p('theory_slides.json'), SlideDeck.fromJson);
    return _slideDecks!;
  }

  FormulaGuideData? _formulaGuide;
  Map<String, dynamic>? _examInfo;

  /// 2026 시험정보 (일정·출제기준·전략) 로드 — raw JSON map
  Future<Map<String, dynamic>?> loadExamInfo() async {
    if (_examInfo != null) return _examInfo;
    try {
      final raw =
          await rootBundle.loadString(_p('exam_info_2026.json'));
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
          await rootBundle.loadString(_p('formula_guide.json'));
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
      final raw = await rootBundle.loadString(_p('silgi.json'));
      _silgi = SilgiData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('silgi.json 로드 실패: $e');
    }
    return _silgi;
  }

  // ─── 왕초보 기초사전 (전 종목 공통, assets/data/common/) ───
  List<BasicTerm>? _basicsDict;
  List<String>? _basicsCategories;

  /// 왕초보 기초사전 로드 — 300+ 필수 단위·용어·기호 (종목 공통)
  Future<List<BasicTerm>> loadBasicsDict() async {
    if (_basicsDict != null) return _basicsDict!;
    try {
      final raw = await rootBundle
          .loadString('assets/data/common/basics_dict.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _basicsCategories = ((map['categories'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      _basicsDict = ((map['basics'] as List?) ?? const [])
          .map((e) => BasicTerm.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('basics_dict.json 로드 실패: $e');
      _basicsDict = <BasicTerm>[];
      _basicsCategories = <String>[];
    }
    return _basicsDict!;
  }

  // ─── 회로도 마스터 (전 종목 공통) ───
  CircuitGuide? _circuitGuide;

  /// 모터 제어반 회로도 가이드 로드 (기호·그리기 STEP·규칙·태그표)
  Future<CircuitGuide?> loadCircuitGuide() async {
    if (_circuitGuide != null) return _circuitGuide;
    try {
      final raw = await rootBundle
          .loadString('assets/data/common/circuit_guide.json');
      _circuitGuide =
          CircuitGuide.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('circuit_guide.json 로드 실패: $e');
      _circuitGuide = null;
    }
    return _circuitGuide;
  }

  /// 기초사전 카테고리 순서 (loadBasicsDict 후 사용)
  List<String> get basicsCategories => _basicsCategories ?? const [];

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
        _p('exams.json'), ExamPaper.fromJson)
      ..sort((a, b) {
        final c = b.year.compareTo(a.year);
        return c != 0 ? c : b.session.compareTo(a.session);
      });
    return _exams!;
  }

  /// 문제은행 총 문항 수(회독 계산용) — 4지선다 유효 문항만 카운트
  Future<int> bankQuestionCount() async {
    final exams = await loadExams();
    var n = 0;
    for (final e in exams) {
      for (final q in e.questions) {
        if (q.options.length == 4 && q.answer >= 1) n++;
      }
    }
    return n;
  }

  /// 데이터에 존재하는 가장 최근 기출 연도 (연도별 세트 기준점)
  Future<int> latestExamYear() async {
    final exams = await loadExams();
    if (exams.isEmpty) return DateTime.now().year;
    return exams.map((e) => e.year).reduce((a, b) => a > b ? a : b);
  }

  /// 최근 [years]년치 기출문제 추출 (연도 내림차순 → 회차 순).
  /// 5/7/10년치 풀기 세트에 사용. 유효 4지선다 문항만 포함.
  Future<List<Question>> questionsByYearRange(int years) async {
    final exams = await loadExams();
    if (exams.isEmpty) return [];
    final latest = exams.map((e) => e.year).reduce((a, b) => a > b ? a : b);
    final minYear = latest - years + 1;
    final papers = exams.where((e) => e.year >= minYear).toList()
      ..sort((a, b) {
        final c = b.year.compareTo(a.year);
        return c != 0 ? c : b.session.compareTo(a.session);
      });
    final out = <Question>[];
    for (final e in papers) {
      for (final q in e.questions) {
        if (q.options.length == 4 && q.answer >= 1) {
          q.examLabel = e.label;
          out.add(q);
        }
      }
    }
    return out;
  }

  /// 특정 연도 범위에 포함되는 회차(시험지) 수 — 세트 안내 표기용
  Future<int> papersInYearRange(int years) async {
    final exams = await loadExams();
    if (exams.isEmpty) return 0;
    final latest = exams.map((e) => e.year).reduce((a, b) => a > b ? a : b);
    final minYear = latest - years + 1;
    return exams.where((e) => e.year >= minYear).length;
  }

  List<SolutionRecipe>? _recipes;
  Map<String, SolutionRecipe>? _recipeByTopic;

  /// 풀이 레시피 로드 (42개 토픽 — 풀이 순서 + 공식 적용법)
  Future<List<SolutionRecipe>> loadRecipes() async {
    if (_recipes != null) return _recipes!;
    _recipes = await _safeLoadList(
        _p('solution_recipes.json'), SolutionRecipe.fromJson);
    _recipeByTopic = {for (final r in _recipes!) r.topic: r};
    return _recipes!;
  }

  /// 토픽으로 레시피 즉시 조회 (loadRecipes 후 사용)
  SolutionRecipe? recipeForTopic(String topic) => _recipeByTopic?[topic];

  Future<List<Mnemonic>> loadMnemonics() async {
    if (_mnemonics != null) return _mnemonics!;
    _mnemonics = await _safeLoadList(
        _p('mnemonics.json'), Mnemonic.fromJson);
    return _mnemonics!;
  }

  Future<List<VideoLink>> loadVideos() async {
    if (_videos != null) return _videos!;
    _videos = await _safeLoadList(
        _p('videos.json'), VideoLink.fromJson);
    return _videos!;
  }

  Future<Map<String, List<TopicFreq>>> loadTopicFreq() async {
    if (_topicFreq != null) return _topicFreq!;
    try {
      final raw = await rootBundle.loadString(_p('topic_freq.json'));
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
        _p('lessons.json'), Lesson.fromJson);
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
        _p('repeat_questions.json'), RepeatCluster.fromJson);
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
