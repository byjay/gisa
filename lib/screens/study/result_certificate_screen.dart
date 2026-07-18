import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/pass_prediction.dart';
import '../../services/quiz_policy.dart';
import '../../services/study_data.dart';
import '../../widgets/tutor_coach.dart';

/// 🏆 합격 성적표 — 100문항 실전 모의고사를 마치면 나오는 결과 화면.
/// 캡처해서 자랑하고 싶은, "990원도 아깝지 않다"를 느끼게 하는 화면.
/// 등급증 스타일 디자인 + 과목별 막대 + 예측 점수 연동.
class ResultCertificateScreen extends StatelessWidget {
  final String examLabel;
  final int correct;
  final int total;
  final Map<String, int> subjectTotal;
  final Map<String, int> subjectCorrect;
  final PassPrediction? prediction;

  const ResultCertificateScreen({
    super.key,
    required this.examLabel,
    required this.correct,
    required this.total,
    required this.subjectTotal,
    required this.subjectCorrect,
    this.prediction,
  });

  int get pct => total == 0 ? 0 : (correct * 100 / total).round();
  bool get gwarakAny {
    for (final s in subjectTotal.keys) {
      final t = subjectTotal[s] ?? 0;
      final c = subjectCorrect[s] ?? 0;
      if (t > 0 && (c * 100 / t) < 40) return true;
    }
    return false;
  }

  bool get passed => QuizPolicy.isPassed(
    correct: correct,
    total: total,
    subjectTotal: subjectTotal,
    subjectCorrect: subjectCorrect,
  );

  /// 등급 뱃지 — 게임화 요소. 90+ S, 80+ A, 70+ B, 60+ C, else D
  (String, Color) get _grade {
    if (pct >= 90) return ('S', const Color(0xFFFFD700));
    if (pct >= 80) return ('A', const Color(0xFF4CAF50));
    if (pct >= 70) return ('B', const Color(0xFF2196F3));
    if (pct >= 60) return ('C', const Color(0xFF9C27B0));
    return ('D', const Color(0xFF757575));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (grade, gradeColor) = _grade;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('합격 성적표'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            children: [
              // 🎓 볼트쌀 결과 코칭 — 합격/불합격/만점 상황별 멘트
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TutorCoach(
                  situation: correct == total
                      ? CoachSituation.resultPerfect
                      : (passed
                            ? CoachSituation.resultPass
                            : CoachSituation.resultFail),
                  level: total > 0 && correct / total >= 0.75
                      ? 2
                      : (total > 0 && correct / total >= 0.45 ? 1 : 0),
                  height: 100,
                ),
              ),
              // ── 등급증 카드 ──────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gradeColor.withValues(alpha: 0.25),
                      const Color(0xFF0B1120),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: gradeColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradeColor.withValues(alpha: 0.35),
                      blurRadius: 30,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '${StudyData.instance.track.name} 필기 $examLabel',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 등급 원형 배지
                    Container(
                      width: 110,
                      height: 110,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            gradeColor.withValues(alpha: 0.9),
                            gradeColor.withValues(alpha: 0.4),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: gradeColor.withValues(alpha: 0.6),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Text(
                        grade,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$correct / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$pct점',
                      style: TextStyle(
                        color: gradeColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: (passed ? Colors.green : Colors.redAccent)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: passed ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                      child: Text(
                        passed
                            ? '🎉 합격권입니다!'
                            : (gwarakAny ? '🚨 과락으로 불합격' : '조금 더! 불합격권'),
                        style: TextStyle(
                          color: passed ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ── 과목별 상세 ──────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '과목별 성적',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final s in subjectTotal.keys) _subjectRow(s),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── 합격 예측 연동 ──────────────────────
              if (prediction != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '이 결과 반영 → 전체 합격 예측 ${prediction!.overall.round()}점',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _copyResult(context),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('결과 텍스트 복사'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: gradeColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.home_rounded, size: 18),
                      label: const Text('홈으로'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subjectRow(String s) {
    final t = subjectTotal[s] ?? 0;
    final c = subjectCorrect[s] ?? 0;
    final p = t == 0 ? 0 : (c * 100 / t).round();
    final gwarak = p < 40;
    final color = gwarak
        ? Colors.redAccent
        : (p >= 60 ? Colors.greenAccent : Colors.orangeAccent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              s,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (p / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              '$p점',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (gwarak)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('⚠', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  void _copyResult(BuildContext context) {
    final buf = StringBuffer();
    buf.writeln('⚡ ${StudyData.instance.track.name} 필기 $examLabel 결과');
    buf.writeln('점수: $correct/$total ($pct점) — ${passed ? "합격권" : "불합격권"}');
    for (final s in subjectTotal.keys) {
      final t = subjectTotal[s] ?? 0;
      final c = subjectCorrect[s] ?? 0;
      final p = t == 0 ? 0 : (c * 100 / t).round();
      buf.writeln('· $s: $c/$t ($p점)');
    }
    buf.writeln(
      '#Cert스터디트래커 #${StudyData.instance.track.name.replaceAll(RegExp(r"[()\s]"), "")}',
    );
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('결과가 복사되었습니다 — 오픈채팅방에 자랑해보세요!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
