import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/magic_effects.dart';
import '../widgets/tutor_avatar.dart';

/// ✨ 프리미엄 온보딩 — 첫 실행 30초 안에 "시험일 → 목표 → 핵심 루프"를 세팅.
/// 오르조 리서치의 "30분 온보딩 루틴" 시사점을 3페이지로 압축.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _idx = 0;

  // 사용자 선택값
  DateTime? _examDate;
  int _dailyGoal = 120;
  String _selectedTutorId = 'soyeon';

  static const _goalOptions = [
    (min: 60, label: '가볍게', desc: '하루 1시간 · 직장인 추천'),
    (min: 120, label: '표준', desc: '하루 2시간 · 3개월 완성'),
    (min: 240, label: '스퍼트', desc: '하루 4시간 · 시험 임박'),
  ];

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      helpText: '시험 예정일을 선택하세요',
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  Future<void> _finish() async {
    final app = context.read<AppProvider>();
    if (_examDate != null) {
      await app.addExam(
        Exam(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: '목표 자격증 필기',
          category: '국가기술자격',
          examDate: _examDate!,
          memo: '온보딩에서 설정한 목표 시험',
          colorValue: 0xFF4F46E5,
        ),
      );
    }
    await app.setGoals(daily: _dailyGoal, weekly: _dailyGoal * 5);
    await app.setSelectedTutor(_selectedTutorId);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.heroGradient),
        child: Stack(
          children: [
            const Positioned.fill(child: SparkleOverlay()),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _page,
                      onPageChanged: (i) => setState(() => _idx = i),
                      children: [
                        _pageShell(
                          emoji: '⚡',
                          title: '자격증 합격,\n마법처럼 만들어 드릴게요',
                          subtitle:
                              '전기기사·전기공사기사·소방설비기사(전기) 지원\n기출·해설 100% · 완전 무료 · 풀기→채점→해설→오답복습 루프',
                          child: _loopPreview(),
                        ),
                        _pageShell(
                          emoji: '',
                          title: '나의 강사를 선택하세요',
                          subtitle: '선택한 선생님이 학습 화면마다 함께하며\n암기·이론·심화 학습을 안내합니다',
                          child: _tutorPicker(),
                        ),
                        _pageShell(
                          emoji: '📅',
                          title: '시험일을 알려주세요',
                          subtitle: 'D-Day에 맞춰 매일 학습 플랜과\n합격 예측 점수를 계산해 드려요',
                          child: _dateCard(),
                        ),
                        _pageShell(
                          emoji: '🎯',
                          title: '하루 목표를 정해주세요',
                          subtitle: '목표를 달성하면 XP·마법 방패를 획득하고\n마법사 레벨이 올라갑니다',
                          child: _goalCard(),
                        ),
                      ],
                    ),
                  ),
                  _bottomBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageShell({
    required String emoji,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          child,
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _loopPreview() {
    const steps = ['풀기', '채점', '해설', '오답복습'];
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 16,
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(
              steps[i],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tutorPicker() {
    return Row(
      children: [
        for (final tutor in tutorProfiles)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: _selectedTutorId == tutor.id
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => setState(() => _selectedTutorId = tutor.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: _selectedTutorId == tutor.id ? 1 : 0.3,
                        ),
                        width: _selectedTutorId == tutor.id ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 145,
                          child: Image.asset(
                            tutor.asset,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          tutor.name.replaceAll(' 선생님', ''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          _selectedTutorId == tutor.id
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: Colors.white,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _dateCard() {
    final d = _examDate;
    final dday = d == null ? null : d.difference(DateTime.now()).inDays + 1;
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d == null ? '탭해서 시험일 선택' : '${d.year}년 ${d.month}월 ${d.day}일',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                d == null ? '나중에 시험 탭에서도 추가할 수 있어요' : '⚡ D-$dday · 지금부터 준비 시작!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goalCard() {
    return Column(
      children: [
        for (final g in _goalOptions) ...[
          Material(
            color: _dailyGoal == g.min
                ? Colors.white.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: () => setState(() => _dailyGoal = g.min),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: _dailyGoal == g.min ? 0.9 : 0.25,
                    ),
                    width: _dailyGoal == g.min ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _dailyGoal == g.min
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${g.label} · 하루 ${g.min ~/ 60}시간',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                          Text(
                            g.desc,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _bottomBar() {
    final isLast = _idx == 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
      child: Row(
        children: [
          // 페이지 인디케이터
          for (var i = 0; i < 4; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 6),
              width: i == _idx ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: i == _idx ? 1 : 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          const Spacer(),
          if (!isLast)
            TextButton(
              onPressed: widget.onDone,
              child: Text(
                '건너뛰기',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            onPressed: isLast
                ? _finish
                : () => _page.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  ),
            child: Text(isLast ? '✨ 마법 학습 시작' : '다음'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }
}
