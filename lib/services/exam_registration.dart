import 'package:hive_flutter/hive_flutter.dart';

/// 🎯 응시 상태 — 특정 회차에 대한 사용자의 응시 계획/결과.
enum ExamPhase { written, practical }

extension ExamPhaseLabel on ExamPhase {
  String get label => this == ExamPhase.written ? '필기' : '실기';
  String get key => this == ExamPhase.written ? 'written' : 'practical';
  static ExamPhase fromKey(String k) =>
      k == 'practical' ? ExamPhase.practical : ExamPhase.written;
}

/// 응시 진행 상태.
enum RegStatus {
  planned, // 응시할게요 (계획)
  registered, // 원서접수 완료
  taken, // 응시했어요 (시험 봄)
  passed, // 합격
  failed, // 불합격
}

extension RegStatusLabel on RegStatus {
  String get label {
    switch (this) {
      case RegStatus.planned:
        return '응시 예정';
      case RegStatus.registered:
        return '접수 완료';
      case RegStatus.taken:
        return '응시 완료';
      case RegStatus.passed:
        return '합격 🎉';
      case RegStatus.failed:
        return '불합격';
    }
  }

  String get key => name;
  static RegStatus fromKey(String k) =>
      RegStatus.values.firstWhere((e) => e.name == k,
          orElse: () => RegStatus.planned);
}

/// 한 회차·단계(필기/실기)에 대한 응시 등록 + 가답안 채점 결과.
class ExamRegistration {
  final String id; // jmCd + roundLabel + phase 조합 해시
  final String jmCd; // 종목 코드
  final String catalogId; // 앱 카탈로그 id
  final String certName; // 자격증 이름
  final String roundLabel; // 회차 라벨
  final ExamPhase phase;
  RegStatus status;

  // 가답안 채점 결과 (사용자가 자신의 답과 발표된 가답안을 대조한 값)
  int? scoredTotal; // 채점한 총 문항
  int? scoredCorrect; // 맞힌 문항
  int? subjectFails; // 과락 과목 수 (필기 40점 미만 과목)
  DateTime? scoredAt;

  ExamRegistration({
    required this.id,
    required this.jmCd,
    required this.catalogId,
    required this.certName,
    required this.roundLabel,
    required this.phase,
    this.status = RegStatus.planned,
    this.scoredTotal,
    this.scoredCorrect,
    this.subjectFails,
    this.scoredAt,
  });

  /// 가답안 점수(100점 환산). 채점 안 했으면 null.
  double? get score {
    if (scoredTotal == null || scoredCorrect == null || scoredTotal == 0) {
      return null;
    }
    return scoredCorrect! / scoredTotal! * 100;
  }

  /// 합격 예상 여부: 평균 60점 이상 + 과락 없음(필기 기준).
  bool? get likelyPass {
    final s = score;
    if (s == null) return null;
    final noFail = (subjectFails ?? 0) == 0;
    return s >= 60 && noFail;
  }

  static String makeId(String jmCd, String roundLabel, ExamPhase phase) =>
      '${jmCd}__${roundLabel}__${phase.key}'.replaceAll(RegExp(r'\s+'), '_');

  Map<String, dynamic> toMap() => {
        'id': id,
        'jmCd': jmCd,
        'catalogId': catalogId,
        'certName': certName,
        'roundLabel': roundLabel,
        'phase': phase.key,
        'status': status.key,
        'scoredTotal': scoredTotal,
        'scoredCorrect': scoredCorrect,
        'subjectFails': subjectFails,
        'scoredAt': scoredAt?.toIso8601String(),
      };

  factory ExamRegistration.fromMap(Map<dynamic, dynamic> m) => ExamRegistration(
        id: m['id'] as String,
        jmCd: (m['jmCd'] as String?) ?? '',
        catalogId: (m['catalogId'] as String?) ?? '',
        certName: (m['certName'] as String?) ?? '',
        roundLabel: (m['roundLabel'] as String?) ?? '',
        phase: ExamPhaseLabel.fromKey((m['phase'] as String?) ?? 'written'),
        status: RegStatusLabel.fromKey((m['status'] as String?) ?? 'planned'),
        scoredTotal: m['scoredTotal'] as int?,
        scoredCorrect: m['scoredCorrect'] as int?,
        subjectFails: m['subjectFails'] as int?,
        scoredAt: (m['scoredAt'] as String?) != null
            ? DateTime.tryParse(m['scoredAt'] as String)
            : null,
      );
}

/// 응시 등록/가답안 데이터를 Hive 로 저장하는 저장소.
class ExamRegistrationStore {
  ExamRegistrationStore._();
  static final ExamRegistrationStore instance = ExamRegistrationStore._();

  static const _boxName = 'exam_registrations';
  Box? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  List<ExamRegistration> all() {
    final b = _box;
    if (b == null) return const [];
    return b.values
        .map((e) => ExamRegistration.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  ExamRegistration? byId(String id) {
    final e = _box?.get(id);
    if (e == null) return null;
    return ExamRegistration.fromMap(Map<dynamic, dynamic>.from(e));
  }

  Future<void> save(ExamRegistration reg) async {
    await _box?.put(reg.id, reg.toMap());
  }

  Future<void> delete(String id) async {
    await _box?.delete(id);
  }
}
