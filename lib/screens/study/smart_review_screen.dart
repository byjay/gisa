import 'package:flutter/material.dart';
import '../../services/progress_service.dart';
import '../../services/study_data.dart';
import '../../widgets/tutor_avatar.dart';
import 'quiz_play_screen.dart';
import '../../widgets/persistent_nav.dart';

/// 스마트 복습 센터 — 상위 자격증 앱(맞추다·전구앱·오르조) 핵심 기능 벤치마킹
/// 1) 자동 오답노트: 틀린 문제만 다시 풀기
/// 2) 북마크: 헷갈린 문제 모아 풀기
/// 3) 약점 토픽 분석: 토픽별 정답률 리포트
/// 4) AI 맞춤 문제집: 약점×빈출도 가중 20문항 자동 추출
class SmartReviewScreen extends StatefulWidget {
  const SmartReviewScreen({super.key});

  @override
  State<SmartReviewScreen> createState() => _SmartReviewScreenState();
}

class _SmartReviewScreenState extends State<SmartReviewScreen> {
  ({int solved, int correct, int attempts, int wrong, int bookmarks})? _sum;
  List<(String, String, int, int)> _weak = [];
  int _dueCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sum = await ProgressService.instance.summary();
    final weak = await ProgressService.instance.weakTopics();
    final due = await ProgressService.instance.dueReviewCount();
    if (!mounted) return;
    setState(() {
      _sum = sum;
      _weak = weak;
      _dueCount = due;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스마트 복습 센터')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryCard(),
                  const SizedBox(height: 14),
                  // 🔁 간격반복(SRS) 오늘의 복습 — 맞힌 건 간격을 늦리고, 틀린 건 다시 모을 늘리는 구조
                  if (_dueCount > 0)
                    _actionCard(
                      icon: Icons.event_repeat,
                      color: Colors.deepPurple,
                      title: '오늘의 복습 카드 ($_dueCount개)',
                      subtitle: '간격반복 스케줄 — 지금 안 보면 기억이 사라져요! 최적의 복습 타이밍입니다',
                      onTap: _startDueReview,
                    ),
                  if (_dueCount > 0) const SizedBox(height: 10),
                  _actionCard(
                    icon: Icons.close_rounded,
                    color: Colors.red,
                    title: '오답 다시 풀기',
                    subtitle:
                        '마지막에 틀린 문제 ${_sum?.wrong ?? 0}개 — 정답 처리되면 자동으로 빠져요',
                    onTap: _startWrongReview,
                  ),
                  _actionCard(
                    icon: Icons.bookmark_rounded,
                    color: Colors.amber.shade700,
                    title: '북마크 문제 풀기',
                    subtitle: '헷갈려서 표시한 문제 ${_sum?.bookmarks ?? 0}개',
                    onTap: _startBookmarkReview,
                  ),
                  _actionCard(
                    icon: Icons.auto_awesome,
                    color: Colors.purple,
                    title: 'AI 맞춤 문제집 20문항',
                    subtitle: '내 약점 토픽 × 출제 빈도를 계산해 지금 가장 풀어야 할 문제를 추출',
                    onTap: _startSmartSet,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '약점 토픽 리포트',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '정답률이 낮은 토픽부터 표시됩니다. (2회 이상 푼 토픽 기준)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (_weak.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const TutorAvatar(
                              mood: TutorMood.thinking,
                              size: 52,
                              headOnly: true,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '아직 데이터가 부족해요.\n문제를 풀면 토픽별 정답률이 자동으로 분석됩니다!',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._weak.map(_weakTile),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard() {
    final s = _sum;
    if (s == null) return const SizedBox.shrink();
    final acc = s.attempts == 0 ? 0 : (s.correct * 100 / s.attempts).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade600, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const TutorAvatar(mood: TutorMood.teaching, size: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '나의 학습 데이터',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _stat('푼 문제', '${s.solved}'),
                    _stat('누적 정답률', '$acc%'),
                    _stat('현재 오답', '${s.wrong}'),
                    _stat('북마크', '${s.bookmarks}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _weakTile((String, String, int, int) row) {
    final (subject, topic, acc, attempts) = row;
    final color = acc < 40
        ? Colors.red
        : acc < 60
        ? Colors.orange
        : Colors.green;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(
          topic,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$subject · $attempts회 풀이',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: acc / 100,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
        trailing: Text(
          '$acc%',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        onTap: () => _startTopicDrill(subject, topic),
      ),
    );
  }

  Future<void> _startDueReview() async {
    final qids = await ProgressService.instance.dueReviewQids();
    final qs = await ProgressService.instance.resolveQuestions(qids);
    if (!mounted) return;
    if (qs.isEmpty) {
      _toast('오늘 복습할 카드가 없어요. 완벽합니다 👏');
      return;
    }
    qs.shuffle();
    await _push('오늘의 복습 카드 (${qs.length}문항)', qs);
  }

  Future<void> _startWrongReview() async {
    final qids = await ProgressService.instance.wrongQids();
    final qs = await ProgressService.instance.resolveQuestions(qids);
    if (!mounted) return;
    if (qs.isEmpty) {
      _toast('현재 오답이 없어요! 완벽합니다 👏');
      return;
    }
    qs.shuffle();
    await _push('오답 다시 풀기 (${qs.length}문항)', qs);
  }

  Future<void> _startBookmarkReview() async {
    final qids = await ProgressService.instance.bookmarkedQids();
    final qs = await ProgressService.instance.resolveQuestions(qids);
    if (!mounted) return;
    if (qs.isEmpty) {
      _toast('북마크한 문제가 없어요. 문제 풀 때 우측 상단 북마크를 눌러 보세요!');
      return;
    }
    await _push('북마크 문제 (${qs.length}문항)', qs);
  }

  Future<void> _startSmartSet() async {
    final qs = await ProgressService.instance.buildSmartSet(count: 20);
    if (!mounted) return;
    if (qs.isEmpty) {
      _toast('문제 데이터를 불러오지 못했습니다.');
      return;
    }
    await _push('AI 맞춤 문제집 (약점×빈출)', qs);
  }

  Future<void> _startTopicDrill(String subject, String topic) async {
    final exams = await StudyData.instance.loadExams();
    final qs = <Question>[];
    for (final e in exams) {
      for (final q in e.questions) {
        if (q.subject == subject && q.topic == topic) {
          q.examLabel = e.label;
          qs.add(q);
        }
      }
    }
    if (!mounted) return;
    if (qs.isEmpty) {
      _toast('해당 토픽 문제를 찾지 못했습니다.');
      return;
    }
    qs.shuffle();
    await _push('$topic 집중 훈련', qs.take(15).toList());
  }

  Future<void> _push(String title, List<Question> qs) async {
    await pushWithNav(
      context,
      QuizPlayScreen(title: title, questions: qs, examMode: false),
      currentSection: 1,
    );
    _load(); // 돌아오면 통계 갱신
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
